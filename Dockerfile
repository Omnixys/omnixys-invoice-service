# syntax=docker/dockerfile:1.14.0

ARG JAVA_VERSION=24
ARG APP_NAME=invoice
ARG APP_VERSION=2025.05.16

# ---------------------------------------------------------------------------------------
# 🧱 Stage 1: builder – Maven Build + Layer-Extraktion
# ---------------------------------------------------------------------------------------
FROM azul/zulu-openjdk:${JAVA_VERSION} AS builder

ARG APP_NAME
ARG APP_VERSION
WORKDIR /source

# Nur relevante Dateien zuerst (für Cache-Effizienz)
COPY pom.xml mvnw ./
COPY .mvn ./.mvn

# Vorab Maven-Dependencies auflösen (besserer Cache)
RUN ./mvnw dependency:go-offline -B || true

# Quellcode hinzufügen
COPY src ./src

# Fat JAR erzeugen und Spring Boot Layers extrahieren
RUN ./mvnw package spring-boot:repackage -Dmaven.test.skip=true -Dspring-boot.build-image.skip=true
RUN JAR_FILE=$(ls ./target/*.jar | grep -v 'original' | head -n 1) && \
    echo "Extracting $JAR_FILE" && \
    java -Djarmode=layertools -jar "$JAR_FILE" extract


# ---------------------------------------------------------------------------------------
# 🧬 Stage 2: final – Minimaler Runtime-Container mit nicht-root User
# ---------------------------------------------------------------------------------------
FROM azul/zulu-openjdk:${JAVA_VERSION}-jre AS final

ARG APP_NAME
ARG APP_VERSION
LABEL org.opencontainers.image.title="${APP_NAME}" \
      org.opencontainers.image.description="Microservice ${APP_NAME} v1 mit Basis-Image Azul Zulu und Ubuntu Jammy" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      org.opencontainers.image.vendor="Omnixys" \
      org.opencontainers.image.authors="caleb.gyamfi@omnixys.com" \
      org.opencontainers.image.base.name="azul/zulu-openjdk:LATEST_VERSION-jre"

WORKDIR /workspace

RUN set -eux; \
    apt-get update; \
    apt-get upgrade --yes; \
    apt-get install --no-install-recommends --yes dumb-init=1.2.5-2 wget; \
    apt-get autoremove -y; \
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/* /tmp/*; \
    groupadd --gid 1000 app; \
    useradd --uid 1000 --gid app --no-create-home app; \
    chown -R app:app /workspace

USER app

# Kopiere extrahierte Spring Boot-Schichten (Layered JAR-Struktur)
COPY --from=builder --chown=app:app /source/dependencies/ /source/spring-boot-loader/ /source/application/ ./

EXPOSE 8080

# Healthcheck für Container-Management (z. B. Docker, Kubernetes)
HEALTHCHECK --interval=30s --timeout=3s --retries=1 \
  CMD wget -qO- --no-check-certificate https://localhost:8080/actuator/health/ | grep UP || exit 1

# Start Spring Boot über Spring Boot Launcher (Layer-Modus)
ENTRYPOINT ["dumb-init", "java", "--enable-preview", "org.springframework.boot.loader.launch.JarLauncher"]

