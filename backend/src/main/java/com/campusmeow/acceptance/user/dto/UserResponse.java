package com.campusmeow.acceptance.user.dto;

import java.time.LocalDate;
import java.time.OffsetDateTime;

import com.campusmeow.acceptance.user.entity.User;

public record UserResponse(Long id, String username, String nickname, LocalDate birthday,
        String school, String className, OffsetDateTime createdAt, OffsetDateTime updatedAt) {
    public static UserResponse from(User user) {
        return new UserResponse(user.getId(), user.getUsername(), user.getNickname(), user.getBirthday(),
                user.getSchool(), user.getClassName(), user.getCreatedAt(), user.getUpdatedAt());
    }
}
