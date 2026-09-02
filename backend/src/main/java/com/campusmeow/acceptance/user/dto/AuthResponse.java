package com.campusmeow.acceptance.user.dto;

import java.time.Instant;

public record AuthResponse(String tokenType, String accessToken, Instant expiresAt, UserResponse user) {
}
