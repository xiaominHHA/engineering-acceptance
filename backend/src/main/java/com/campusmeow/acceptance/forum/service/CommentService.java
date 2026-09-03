package com.campusmeow.acceptance.forum.service;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import com.campusmeow.acceptance.common.error.BusinessException;
import com.campusmeow.acceptance.forum.document.Comment;
import com.campusmeow.acceptance.forum.dto.CommentRequest;
import com.campusmeow.acceptance.forum.dto.CommentResponse;
import com.campusmeow.acceptance.forum.repository.CommentRepository;
import com.campusmeow.acceptance.user.entity.User;
import com.campusmeow.acceptance.user.repository.UserRepository;

@Service
public class CommentService {
    private final CommentRepository repository;
    private final PostService postService;
    private final UserRepository userRepository;

    public CommentService(CommentRepository repository, PostService postService,
            UserRepository userRepository) {
        this.repository = repository;
        this.postService = postService;
        this.userRepository = userRepository;
    }

    public List<CommentResponse> list(String postId, int page, int size) {
        postService.find(postId);
        return enrich(repository.findByPostIdOrderByCreatedAtAsc(
                postId, PageRequest.of(page, size)).getContent());
    }

    public CommentResponse create(Long authorUserId, String postId, CommentRequest request) {
        postService.find(postId);
        Comment replyTarget = null;
        if (request.replyToCommentId() != null) {
            replyTarget = find(request.replyToCommentId());
            if (!postId.equals(replyTarget.getPostId())) {
                throw new BusinessException(BusinessException.Code.INVALID_REPLY_TARGET,
                        "Reply target must belong to the same post");
            }
        }
        Comment comment = new Comment();
        comment.setPostId(postId);
        comment.setAuthorUserId(authorUserId);
        comment.setContent(request.content().trim());
        comment.setReplyToCommentId(replyTarget == null ? null : replyTarget.getId());
        comment.setCreatedAt(Instant.now());
        return enrich(List.of(repository.save(comment))).getFirst();
    }

    public void delete(Long requesterUserId, String postId, String commentId) {
        Comment comment = find(commentId);
        if (!postId.equals(comment.getPostId())) {
            throw new BusinessException(BusinessException.Code.COMMENT_NOT_FOUND,
                    "Comment was not found");
        }
        if (!requesterUserId.equals(comment.getAuthorUserId())) {
            throw new BusinessException(BusinessException.Code.ACCESS_DENIED,
                    "Only the comment author can delete this comment");
        }
        repository.delete(comment);
    }

    private Comment find(String commentId) {
        return repository.findById(commentId)
                .orElseThrow(() -> new BusinessException(
                        BusinessException.Code.COMMENT_NOT_FOUND, "Comment was not found"));
    }

    private List<CommentResponse> enrich(List<Comment> comments) {
        Map<String, Comment> replies = new HashMap<>();
        List<String> replyIds = comments.stream().map(Comment::getReplyToCommentId)
                .filter(id -> id != null).distinct().toList();
        repository.findAllById(replyIds).forEach(comment -> replies.put(comment.getId(), comment));
        Set<Long> userIds = comments.stream().map(Comment::getAuthorUserId).collect(Collectors.toSet());
        replies.values().stream().map(Comment::getAuthorUserId).forEach(userIds::add);
        Map<Long, User> users = userRepository.findAllById(userIds).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        return comments.stream().map(comment -> {
            Comment reply = replies.get(comment.getReplyToCommentId());
            return CommentResponse.from(comment,
                    PostService.nickname(users.get(comment.getAuthorUserId())),
                    reply == null ? null : PostService.nickname(users.get(reply.getAuthorUserId())));
        }).toList();
    }
}
