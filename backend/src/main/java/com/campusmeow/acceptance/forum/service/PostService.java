package com.campusmeow.acceptance.forum.service;

import java.time.Instant;
import java.util.List;

import org.springframework.stereotype.Service;

import com.campusmeow.acceptance.forum.document.Post;
import com.campusmeow.acceptance.forum.dto.PostRequest;
import com.campusmeow.acceptance.forum.dto.PostResponse;
import com.campusmeow.acceptance.forum.repository.PostRepository;

@Service
public class PostService {
    private final PostRepository repository;

    public PostService(PostRepository repository) { this.repository = repository; }

    public List<PostResponse> list() {
        return repository.findAll().stream().map(PostResponse::from).toList();
    }

    public PostResponse create(PostRequest request) {
        Instant now = Instant.now();
        Post post = new Post();
        post.setAuthorUserId(request.authorUserId());
        post.setTitle(request.title());
        post.setContent(request.content());
        post.setCreatedAt(now);
        post.setUpdatedAt(now);
        return PostResponse.from(repository.save(post));
    }
}
