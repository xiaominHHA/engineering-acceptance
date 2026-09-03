package com.campusmeow.acceptance.forum.repository;

import java.util.List;

import org.springframework.data.mongodb.repository.MongoRepository;

import com.campusmeow.acceptance.forum.document.PostLike;

public interface PostLikeRepository extends MongoRepository<PostLike, String> {
    List<PostLike> findByPostIdIn(List<String> postIds);
    void deleteByPostIdAndUserId(String postId, Long userId);
    void deleteByPostId(String postId);
}
