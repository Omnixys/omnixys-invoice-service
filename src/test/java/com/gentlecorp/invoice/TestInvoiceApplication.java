package com.gentlecorp.invoice;

import org.springframework.boot.SpringApplication;

public class TestInvoiceApplication {

    public static void main(String[] args) {
        SpringApplication.from(InvoiceApplication::main).with(TestcontainersConfiguration.class).run(args);
    }

}
