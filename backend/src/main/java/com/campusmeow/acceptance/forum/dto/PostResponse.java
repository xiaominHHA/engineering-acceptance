package com.campusmeow.acceptance.forum.dto;

import java.time.Instant;

import com.campusmeow.acceptance.forum.document.Post;

public record PostResponse(String id, Long authorUserId, String title, String content,
        Instant createdAt, Instant updatedAt) {
    public static PostResponse from(Post post) {
        return new PostResponse(post.getId(), post.getAuthorUserId(), post.getTitle(), post.getContent(),
                post.getCreatedAt(), post.getUpdatedAt());
    }
}
