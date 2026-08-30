package com.campusmeow.acceptance;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.campusmeow.acceptance.user.entity.User;
import com.campusmeow.acceptance.user.repository.UserRepository;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class BusinessIntegrationTests {

    private static final Pattern ID_PATTERN = Pattern.compile("\\\"id\\\":(\\d+)");

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    void completesUserAndForumApiFlowAgainstRealDatabases() throws Exception {
        MvcResult registration = mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"api-integration-user","password":"password123",
                                 "nickname":"API Integration User"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("api-integration-user"))
                .andExpect(jsonPath("$.passwordHash").doesNotExist())
                .andReturn();

        String registrationBody = registration.getResponse().getContentAsString();
        Matcher idMatcher = ID_PATTERN.matcher(registrationBody);
        assertThat(idMatcher.find()).isTrue();
        long userId = Long.parseLong(idMatcher.group(1));

        User storedUser = userRepository.findByUsername("api-integration-user").orElseThrow();
        assertThat(storedUser.getPasswordHash()).isNotEqualTo("password123");
        assertThat(passwordEncoder.matches("password123", storedUser.getPasswordHash())).isTrue();

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"api-integration-user","password":"password123"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(userId))
                .andExpect(jsonPath("$.passwordHash").doesNotExist());

        mockMvc.perform(get("/api/users/{id}", userId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nickname").value("API Integration User"))
                .andExpect(jsonPath("$.passwordHash").doesNotExist());

        mockMvc.perform(put("/api/users/{id}", userId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nickname":"Updated API User","birthday":"2001-02-03",
                                 "school":"Campus Meow","className":"Class 1"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nickname").value("Updated API User"))
                .andExpect(jsonPath("$.passwordHash").doesNotExist());

        mockMvc.perform(post("/api/posts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"authorUserId":%d,"title":"Integration post",
                                 "content":"Stored in real MongoDB"}
                                """.formatted(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Integration post"));

        mockMvc.perform(get("/api/posts"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].title")
                        .value(org.hamcrest.Matchers.hasItem("Integration post")));
    }
}
