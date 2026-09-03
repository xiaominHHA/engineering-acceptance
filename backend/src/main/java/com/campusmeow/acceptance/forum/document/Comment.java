package com.campusmeow.acceptance.forum.document;

import java.time.Instant;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("comments")
public class Comment {
    @Id
    private String id;
    private String postId;
    private Long authorUserId;
    private String content;
    private String replyToCommentId;
    private Instant createdAt;

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getPostId() { return postId; }
    public void setPostId(String postId) { this.postId = postId; }
    public Long getAuthorUserId() { return authorUserId; }
    public void setAuthorUserId(Long authorUserId) { this.authorUserId = authorUserId; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public String getReplyToCommentId() { return replyToCommentId; }
    public void setReplyToCommentId(String replyToCommentId) { this.replyToCommentId = replyToCommentId; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
