package com.omnixys.invoice.models.payload;

import java.math.BigDecimal;

public record InfoPayload(
    int count,
    BigDecimal totalAmount
) {
}
