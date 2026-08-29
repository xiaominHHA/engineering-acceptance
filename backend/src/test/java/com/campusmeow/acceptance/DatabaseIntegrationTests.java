package com.campusmeow.acceptance;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class DatabaseIntegrationTests {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private MongoTemplate mongoTemplate;

    @Test
    void readsFixedMySqlFixture() {
        String nickname = jdbcTemplate.queryForObject(
                "SELECT nickname FROM test_users WHERE id = 1", String.class);
        assertThat(nickname).isEqualTo("fixed-test-user");
    }

    @Test
    void readsFixedMongoFixture() {
        String title = mongoTemplate.getCollection("test_posts")
                .find(new org.bson.Document("_id", "fixed-test-post"))
                .first()
                .getString("title");
        assertThat(title).isEqualTo("Fixed test post");
    }
}
