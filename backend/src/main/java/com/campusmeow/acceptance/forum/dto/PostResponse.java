package com.campusmeow.acceptance.forum.dto;

import java.time.Instant;

import com.campusmeow.acceptance.forum.document.Post;

public record PostResponse(String id, Long authorUserId, String authorNickname, String title, String content,
        Instant createdAt, Instant updatedAt, long likeCount, long commentCount,
        boolean likedByCurrentUser) {
    public static PostResponse from(Post post, String authorNickname, long likeCount,
            long commentCount, boolean likedByCurrentUser) {
        return new PostResponse(post.getId(), post.getAuthorUserId(), authorNickname,
                post.getTitle(), post.getContent(),
                post.getCreatedAt(), post.getUpdatedAt(), likeCount, commentCount,
                likedByCurrentUser);
    }
}
