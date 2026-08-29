package com.campusmeow.acceptance.user.dto;

import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UserUpdateRequest(
        @NotBlank @Size(max = 100) String nickname,
        LocalDate birthday,
        @Size(max = 150) String school,
        @Size(max = 100) String className) {
}
