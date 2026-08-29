package com.campusmeow.acceptance;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;

import com.campusmeow.acceptance.forum.document.Post;
import com.campusmeow.acceptance.forum.repository.PostRepository;
import com.campusmeow.acceptance.user.entity.User;
import com.campusmeow.acceptance.user.repository.UserRepository;

@SpringBootTest
@ActiveProfiles("test")
class BusinessIntegrationTests {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PostRepository postRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    void storesHashedUserAndReadsProfileFromMysql() {
        User user = new User();
        user.setUsername("integration-user");
        user.setPasswordHash(passwordEncoder.encode("password123"));
        user.setNickname("Integration User");
        User saved = userRepository.save(user);

        assertThat(saved.getPasswordHash()).isNotEqualTo("password123");
        assertThat(passwordEncoder.matches("password123", saved.getPasswordHash())).isTrue();
        assertThat(userRepository.findById(saved.getId())).isPresent();
    }

    @Test
    void storesAndReadsPostFromMongo() {
        Post post = new Post();
        post.setAuthorUserId(1L);
        post.setTitle("Integration post");
        post.setContent("Stored in MongoDB");
        Post saved = postRepository.save(post);

        assertThat(postRepository.findById(saved.getId())).get().extracting(Post::getTitle)
                .isEqualTo("Integration post");
    }
}
