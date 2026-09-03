package com.campusmeow.acceptance.forum.service;

import java.time.Instant;

import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;

import com.campusmeow.acceptance.forum.document.PostLike;

@Service
public class PostLikeService {
    private final PostService postService;
    private final MongoTemplate mongoTemplate;

    public PostLikeService(PostService postService, MongoTemplate mongoTemplate) {
        this.postService = postService;
        this.mongoTemplate = mongoTemplate;
    }

    public void like(Long userId, String postId) {
        postService.find(postId);
        Query query = Query.query(Criteria.where("postId").is(postId).and("userId").is(userId));
        Update update = new Update().setOnInsert("postId", postId)
                .setOnInsert("userId", userId).setOnInsert("createdAt", Instant.now());
        mongoTemplate.upsert(query, update, PostLike.class);
    }

    public void unlike(Long userId, String postId) {
        postService.find(postId);
        Query query = Query.query(Criteria.where("postId").is(postId).and("userId").is(userId));
        mongoTemplate.remove(query, PostLike.class);
    }
}
