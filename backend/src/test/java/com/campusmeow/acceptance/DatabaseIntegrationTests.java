package com.campusmeow.acceptance;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.jdbc.Sql;

@SpringBootTest
@ActiveProfiles("test")
class DatabaseIntegrationTests {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private MongoTemplate mongoTemplate;

    @Test
    @Sql("/mysql-fixture.sql")
    void readsFixedMySqlFixture() {
        String nickname = jdbcTemplate.queryForObject(
                "SELECT nickname FROM users WHERE id = 1001", String.class);
        assertThat(nickname).isEqualTo("Fixed Test User");
    }

    @Test
    void flywayCreatedAndRecordedTheUsersSchema() {
        Integer usersTableCount = jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                FROM information_schema.tables
                WHERE table_schema = DATABASE() AND table_name = 'users'
                """, Integer.class);
        Integer successfulMigrationCount = jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                FROM flyway_schema_history
                WHERE version = '1' AND success = 1
                """, Integer.class);

        assertThat(usersTableCount).isEqualTo(1);
        assertThat(successfulMigrationCount).isEqualTo(1);
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
