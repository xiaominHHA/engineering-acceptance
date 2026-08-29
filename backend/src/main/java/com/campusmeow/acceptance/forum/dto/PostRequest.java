package com.campusmeow.acceptance.forum.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record PostRequest(
        @NotNull Long authorUserId,
        @NotBlank @Size(max = 200) String title,
        @NotBlank @Size(max = 10000) String content) {
}
