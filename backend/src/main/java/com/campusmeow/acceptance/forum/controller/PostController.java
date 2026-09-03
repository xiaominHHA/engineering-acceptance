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
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.campusmeow.acceptance.forum.dto.PostRequest;
import com.campusmeow.acceptance.forum.dto.PostResponse;
import com.campusmeow.acceptance.forum.service.PostLikeService;
import com.campusmeow.acceptance.forum.service.PostService;

@Validated
@RestController
@RequestMapping("/api/posts")
public class PostController {
    private final PostService service;
    private final PostLikeService likeService;

    public PostController(PostService service, PostLikeService likeService) {
        this.service = service;
        this.likeService = likeService;
    }

    @GetMapping
    public List<PostResponse> list(
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(50) int size,
            @AuthenticationPrincipal Jwt principal) {
        return service.list(page, size, userId(principal));
    }

    @GetMapping("/{id}")
    public PostResponse get(@PathVariable String id, @AuthenticationPrincipal Jwt principal) {
        return service.get(id, userId(principal));
    }

    @PostMapping
    public PostResponse create(@Valid @RequestBody PostRequest request,
            @AuthenticationPrincipal Jwt principal) {
        return service.create(userId(principal), request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable String id, @AuthenticationPrincipal Jwt principal) {
        service.delete(userId(principal), id);
    }

    @PutMapping("/{id}/like")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void like(@PathVariable String id, @AuthenticationPrincipal Jwt principal) {
        likeService.like(userId(principal), id);
    }

    @DeleteMapping("/{id}/like")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unlike(@PathVariable String id, @AuthenticationPrincipal Jwt principal) {
        likeService.unlike(userId(principal), id);
    }

    private static Long userId(Jwt principal) {
        return principal == null ? null : Long.valueOf(principal.getSubject());
    }
}
