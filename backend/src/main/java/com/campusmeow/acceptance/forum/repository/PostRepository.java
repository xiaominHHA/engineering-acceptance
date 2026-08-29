package com.campusmeow.acceptance.forum.repository;

import org.springframework.data.mongodb.repository.MongoRepository;

import com.campusmeow.acceptance.forum.document.Post;

public interface PostRepository extends MongoRepository<Post, String> {
}
