package com.campusmeow.acceptance.forum.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.data.domain.Sort.Direction;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.index.Index;
import org.springframework.stereotype.Component;

import com.campusmeow.acceptance.forum.document.Comment;
import com.campusmeow.acceptance.forum.document.Post;
import com.campusmeow.acceptance.forum.document.PostLike;

@Component
public class ForumMongoIndexInitializer implements ApplicationRunner {
    private final MongoTemplate mongoTemplate;

    public ForumMongoIndexInitializer(MongoTemplate mongoTemplate) {
        this.mongoTemplate = mongoTemplate;
    }

    @Override
    public void run(ApplicationArguments args) {
        mongoTemplate.indexOps(Post.class).ensureIndex(
                new Index().on("createdAt", Direction.DESC).named("posts_created_at_desc"));
        mongoTemplate.indexOps(Comment.class).ensureIndex(new Index()
                .on("postId", Direction.ASC).on("createdAt", Direction.ASC)
                .named("comments_post_created_at"));
        mongoTemplate.indexOps(PostLike.class).ensureIndex(new Index()
                .on("postId", Direction.ASC).on("userId", Direction.ASC)
                .unique().named("post_likes_post_user_unique"));
    }
}
