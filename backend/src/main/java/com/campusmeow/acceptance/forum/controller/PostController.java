package com.campusmeow.acceptance.forum.controller;

import java.util.List;

import jakarta.validation.Valid;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.campusmeow.acceptance.forum.dto.PostRequest;
import com.campusmeow.acceptance.forum.dto.PostResponse;
import com.campusmeow.acceptance.forum.service.PostService;

@RestController
@RequestMapping("/api/posts")
public class PostController {
    private final PostService service;

    public PostController(PostService service) { this.service = service; }

    @GetMapping
    public List<PostResponse> list() { return service.list(); }

    @PostMapping
    public PostResponse create(@Valid @RequestBody PostRequest request) { return service.create(request); }
}
