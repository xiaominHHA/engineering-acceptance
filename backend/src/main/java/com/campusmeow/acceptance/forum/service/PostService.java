package com.campusmeow.acceptance.forum.service;

import java.time.Instant;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.List;

import org.springframework.stereotype.Service;

import com.campusmeow.acceptance.forum.document.Post;
import com.campusmeow.acceptance.forum.dto.PostRequest;
import com.campusmeow.acceptance.forum.dto.PostResponse;
import com.campusmeow.acceptance.forum.repository.PostRepository;
import com.campusmeow.acceptance.common.error.BusinessException;
import com.campusmeow.acceptance.user.entity.User;
import com.campusmeow.acceptance.user.repository.UserRepository;

@Service
public class PostService {
    private static final String UNKNOWN_AUTHOR = "社区用户";

    private final PostRepository repository;
    private final UserRepository userRepository;

    public PostService(PostRepository repository, UserRepository userRepository) {
        this.repository = repository;
        this.userRepository = userRepository;
    }

    public List<PostResponse> list() {
        List<Post> posts = repository.findAll();
        Set<Long> authorIds = posts.stream()
                .map(Post::getAuthorUserId)
                .collect(Collectors.toSet());
        Map<Long, User> authors = userRepository.findAllById(authorIds).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        return posts.stream()
                .map(post -> PostResponse.from(post, nickname(authors.get(post.getAuthorUserId()))))
                .toList();
    }

    public PostResponse create(Long authorUserId, PostRequest request) {
        Instant now = Instant.now();
        Post post = new Post();
        post.setAuthorUserId(authorUserId);
        post.setTitle(request.title());
        post.setContent(request.content());
        post.setCreatedAt(now);
        post.setUpdatedAt(now);
        Post saved = repository.save(post);
        return PostResponse.from(saved, nickname(userRepository.findById(authorUserId).orElse(null)));
    }

    public void delete(Long requesterUserId, String postId) {
        Post post = repository.findById(postId)
                .orElseThrow(() -> new BusinessException(
                        BusinessException.Code.POST_NOT_FOUND, "Post was not found"));
        if (!requesterUserId.equals(post.getAuthorUserId())) {
            throw new BusinessException(BusinessException.Code.ACCESS_DENIED,
                    "Only the post author can delete this post");
        }
        repository.delete(post);
    }

    private static String nickname(User user) {
        return user == null ? UNKNOWN_AUTHOR : user.getNickname();
    }
}
