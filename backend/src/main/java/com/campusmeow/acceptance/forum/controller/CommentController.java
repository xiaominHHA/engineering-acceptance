package com.campusmeow.acceptance.forum.controller;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.campusmeow.acceptance.forum.dto.CommentRequest;
import com.campusmeow.acceptance.forum.dto.CommentResponse;
import com.campusmeow.acceptance.forum.service.CommentService;

@Validated
@RestController
@RequestMapping("/api/posts/{postId}/comments")
public class CommentController {
    private final CommentService service;

    public CommentController(CommentService service) {
        this.service = service;
    }

    @GetMapping
    public List<CommentResponse> list(@PathVariable String postId,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "30") @Min(1) @Max(50) int size) {
        return service.list(postId, page, size);
    }

    @PostMapping
    public CommentResponse create(@PathVariable String postId,
            @Valid @RequestBody CommentRequest request,
            @AuthenticationPrincipal Jwt principal) {
        return service.create(Long.valueOf(principal.getSubject()), postId, request);
    }

    @DeleteMapping("/{commentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable String postId, @PathVariable String commentId,
            @AuthenticationPrincipal Jwt principal) {
        service.delete(Long.valueOf(principal.getSubject()), postId, commentId);
    }
}
