package com.campusmeow.acceptance.forum.service;

import java.time.Instant;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import com.campusmeow.acceptance.common.error.BusinessException;
import com.campusmeow.acceptance.forum.document.Comment;
import com.campusmeow.acceptance.forum.document.Post;
import com.campusmeow.acceptance.forum.document.PostLike;
import com.campusmeow.acceptance.forum.dto.PostRequest;
import com.campusmeow.acceptance.forum.dto.PostResponse;
import com.campusmeow.acceptance.forum.repository.CommentRepository;
import com.campusmeow.acceptance.forum.repository.PostLikeRepository;
import com.campusmeow.acceptance.forum.repository.PostRepository;
import com.campusmeow.acceptance.user.entity.User;
import com.campusmeow.acceptance.user.repository.UserRepository;

@Service
public class PostService {
    private static final String UNKNOWN_AUTHOR = "社区用户";

    private final PostRepository repository;
    private final PostLikeRepository likeRepository;
    private final CommentRepository commentRepository;
    private final UserRepository userRepository;

    public PostService(PostRepository repository, PostLikeRepository likeRepository,
            CommentRepository commentRepository, UserRepository userRepository) {
        this.repository = repository;
        this.likeRepository = likeRepository;
        this.commentRepository = commentRepository;
        this.userRepository = userRepository;
    }

    public List<PostResponse> list(int page, int size, Long currentUserId) {
        return enrich(repository.findAllByOrderByCreatedAtDesc(PageRequest.of(page, size)).getContent(),
                currentUserId);
    }

    public PostResponse get(String postId, Long currentUserId) {
        return enrich(List.of(find(postId)), currentUserId).getFirst();
    }

    public PostResponse create(Long authorUserId, PostRequest request) {
        Instant now = Instant.now();
        Post post = new Post();
        post.setAuthorUserId(authorUserId);
        post.setTitle(request.title().trim());
        post.setContent(request.content().trim());
        post.setCreatedAt(now);
        post.setUpdatedAt(now);
        return enrich(List.of(repository.save(post)), authorUserId).getFirst();
    }

    public void delete(Long requesterUserId, String postId) {
        Post post = find(postId);
        if (!requesterUserId.equals(post.getAuthorUserId())) {
            throw new BusinessException(BusinessException.Code.ACCESS_DENIED,
                    "Only the post author can delete this post");
        }
        repository.delete(post);
        commentRepository.deleteByPostId(postId);
        likeRepository.deleteByPostId(postId);
    }

    Post find(String postId) {
        return repository.findById(postId)
                .orElseThrow(() -> new BusinessException(
                        BusinessException.Code.POST_NOT_FOUND, "Post was not found"));
    }

    private List<PostResponse> enrich(List<Post> posts, Long currentUserId) {
        List<String> postIds = posts.stream().map(Post::getId).toList();
        Set<Long> authorIds = posts.stream().map(Post::getAuthorUserId).collect(Collectors.toSet());
        Map<Long, User> authors = userRepository.findAllById(authorIds).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        Map<String, Long> likeCounts = new HashMap<>();
        Set<String> likedPostIds = new HashSet<>();
        for (PostLike like : postIds.isEmpty() ? List.<PostLike>of()
                : likeRepository.findByPostIdIn(postIds)) {
            likeCounts.merge(like.getPostId(), 1L, Long::sum);
            if (currentUserId != null && currentUserId.equals(like.getUserId())) {
                likedPostIds.add(like.getPostId());
            }
        }
        Map<String, Long> commentCounts = new HashMap<>();
        for (Comment comment : postIds.isEmpty() ? List.<Comment>of()
                : commentRepository.findByPostIdIn(postIds)) {
            commentCounts.merge(comment.getPostId(), 1L, Long::sum);
        }
        return posts.stream().map(post -> PostResponse.from(post,
                nickname(authors.get(post.getAuthorUserId())),
                likeCounts.getOrDefault(post.getId(), 0L),
                commentCounts.getOrDefault(post.getId(), 0L),
                likedPostIds.contains(post.getId()))).toList();
    }

    static String nickname(User user) {
        return user == null ? UNKNOWN_AUTHOR : user.getNickname();
    }
}
