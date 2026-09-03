package com.campusmeow.acceptance.forum.dto;

import java.time.Instant;

import com.campusmeow.acceptance.forum.document.Comment;

public record CommentResponse(String id, String postId, Long authorUserId,
        String authorNickname, String content, String replyToCommentId,
        String replyToNickname, Instant createdAt) {
    public static CommentResponse from(Comment comment, String authorNickname,
            String replyToNickname) {
        return new CommentResponse(comment.getId(), comment.getPostId(),
                comment.getAuthorUserId(), authorNickname, comment.getContent(),
                comment.getReplyToCommentId(), replyToNickname, comment.getCreatedAt());
    }
}
