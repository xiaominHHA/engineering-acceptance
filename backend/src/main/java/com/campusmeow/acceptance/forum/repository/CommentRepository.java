package com.campusmeow.acceptance.forum.repository;

import java.util.List;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.MongoRepository;

import com.campusmeow.acceptance.forum.document.Comment;

public interface CommentRepository extends MongoRepository<Comment, String> {
    Page<Comment> findByPostIdOrderByCreatedAtAsc(String postId, Pageable pageable);
    List<Comment> findByPostIdIn(List<String> postIds);
    void deleteByPostId(String postId);
}
