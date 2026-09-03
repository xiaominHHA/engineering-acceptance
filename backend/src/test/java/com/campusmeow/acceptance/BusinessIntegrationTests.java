package com.campusmeow.acceptance;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import com.campusmeow.acceptance.user.entity.User;
import com.campusmeow.acceptance.user.repository.UserRepository;
import com.campusmeow.acceptance.forum.document.Post;
import com.campusmeow.acceptance.forum.document.PostLike;
import com.campusmeow.acceptance.forum.repository.PostRepository;
import com.campusmeow.acceptance.forum.repository.CommentRepository;
import com.campusmeow.acceptance.forum.repository.PostLikeRepository;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class BusinessIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JwtEncoder jwtEncoder;

    @MockitoSpyBean
    private UserRepository userRepository;

    @Autowired
    private PostRepository postRepository;

    @Autowired
    private CommentRepository commentRepository;

    @Autowired
    private PostLikeRepository postLikeRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    void completesAuthenticatedUserAndForumApiFlowAgainstRealDatabases() throws Exception {
        AuthenticatedUser authenticated = register(
                "api-integration-user", "password123", "API Integration User");

        User storedUser = userRepository.findByUsername("api-integration-user").orElseThrow();
        assertThat(storedUser.getPasswordHash()).isNotEqualTo("password123");
        assertThat(passwordEncoder.matches("password123", storedUser.getPasswordHash())).isTrue();

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"api-integration-user","password":"password123"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.accessToken").isString())
                .andExpect(jsonPath("$.user.id").value(authenticated.userId()))
                .andExpect(jsonPath("$.user.passwordHash").doesNotExist());

        mockMvc.perform(authenticated(get("/api/users/{id}", authenticated.userId()), authenticated.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nickname").value("API Integration User"))
                .andExpect(jsonPath("$.passwordHash").doesNotExist());

        mockMvc.perform(authenticated(put("/api/users/{id}", authenticated.userId()), authenticated.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"nickname":"Updated API User","birthday":"2001-02-03",
                                 "school":"Campus Meow","className":"Class 1"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nickname").value("Updated API User"))
                .andExpect(jsonPath("$.passwordHash").doesNotExist());

        mockMvc.perform(authenticated(post("/api/posts"), authenticated.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"authorUserId":999999,"title":"Integration post",
                                 "content":"Stored in real MongoDB"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.authorUserId").value(authenticated.userId()))
                .andExpect(jsonPath("$.authorNickname").value("Updated API User"))
                .andExpect(jsonPath("$.title").value("Integration post"));

        mockMvc.perform(get("/api/posts"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].title")
                        .value(org.hamcrest.Matchers.hasItem("Integration post")));
    }

    @Test
    void enforcesAuthenticationOwnershipAndServerAuthoritativePostAuthor() throws Exception {
        AuthenticatedUser userA = register("security-user-a", "password123", "Security A");
        AuthenticatedUser userB = register("security-user-b", "password123", "Security B");

        mockMvc.perform(put("/api/users/{id}", userA.userId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validProfile("No Token")))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_REQUIRED"));

        mockMvc.perform(authenticated(put("/api/users/{id}", userB.userId()), userA.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validProfile("Forbidden")))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ACCESS_DENIED"));

        mockMvc.perform(authenticated(put("/api/users/{id}", userA.userId()), userA.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validProfile("Owner Updated")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nickname").value("Owner Updated"));

        mockMvc.perform(post("/api/posts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Anonymous\",\"content\":\"Denied\"}"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(authenticated(post("/api/posts"), userA.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"authorUserId":%d,"title":"Authoritative",
                                 "content":"The token identity wins"}
                                """.formatted(userB.userId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.authorUserId").value(userA.userId()));
    }

    @Test
    void rejectsInvalidAndExpiredBearerTokens() throws Exception {
        AuthenticatedUser user = register("token-test-user", "password123", "Token User");

        mockMvc.perform(get("/api/users/{id}", user.userId())
                        .header(HttpHeaders.AUTHORIZATION, "Bearer invalid-token"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_REQUIRED"));

        Instant now = Instant.now();
        JwtClaimsSet expiredClaims = JwtClaimsSet.builder()
                .issuer("engineering-acceptance-backend")
                .subject(Long.toString(user.userId()))
                .issuedAt(now.minusSeconds(120))
                .expiresAt(now.minusSeconds(60))
                .build();
        String expiredToken = jwtEncoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), expiredClaims)).getTokenValue();

        mockMvc.perform(get("/api/users/{id}", user.userId())
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + expiredToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_REQUIRED"));
    }

    @Test
    void enrichesPostNicknamesWithOneBatchUserLookupAndStableFallback() throws Exception {
        AuthenticatedUser userA = register("nickname-user-a", "password123", "Nickname A");
        AuthenticatedUser userB = register("nickname-user-b", "password123", "Nickname B");

        mockMvc.perform(authenticated(post("/api/posts"), userA.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Post A\",\"content\":\"Content A\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.authorNickname").value("Nickname A"));
        mockMvc.perform(authenticated(post("/api/posts"), userB.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Post B\",\"content\":\"Content B\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.authorNickname").value("Nickname B"));

        Post unknownAuthor = new Post();
        unknownAuthor.setAuthorUserId(99999999L);
        unknownAuthor.setTitle("Unknown author");
        unknownAuthor.setContent("Fallback nickname");
        unknownAuthor.setCreatedAt(Instant.now());
        unknownAuthor.setUpdatedAt(Instant.now());
        postRepository.save(unknownAuthor);

        clearInvocations(userRepository);
        mockMvc.perform(get("/api/posts"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.title == 'Post A')].authorNickname")
                        .value(org.hamcrest.Matchers.hasItem("Nickname A")))
                .andExpect(jsonPath("$[?(@.title == 'Post B')].authorNickname")
                        .value(org.hamcrest.Matchers.hasItem("Nickname B")))
                .andExpect(jsonPath("$[?(@.title == 'Unknown author')].authorNickname")
                        .value(org.hamcrest.Matchers.hasItem("社区用户")));
        verify(userRepository, times(1)).findAllById(any());
    }

    @Test
    void onlyPostAuthorCanDeleteAndMissingPostReturnsNotFound() throws Exception {
        AuthenticatedUser author = register("delete-author", "password123", "Delete Author");
        AuthenticatedUser other = register("delete-other", "password123", "Delete Other");
        MvcResult created = mockMvc.perform(authenticated(post("/api/posts"), author.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Delete me\",\"content\":\"Owned post\"}"))
                .andExpect(status().isOk())
                .andReturn();
        String postId = objectMapper.readTree(created.getResponse().getContentAsByteArray())
                .path("id").asText();

        mockMvc.perform(delete("/api/posts/{id}", postId))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(authenticated(delete("/api/posts/{id}", postId), other.token()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ACCESS_DENIED"));
        assertThat(postRepository.existsById(postId)).isTrue();

        mockMvc.perform(authenticated(delete("/api/posts/{id}", "missing-post"), author.token()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("POST_NOT_FOUND"));

        mockMvc.perform(authenticated(delete("/api/posts/{id}", postId), author.token()))
                .andExpect(status().isNoContent());
        assertThat(postRepository.existsById(postId)).isFalse();
    }

    @Test
    void supportsBoundedPaginationDetailAndIdempotentLikes() throws Exception {
        AuthenticatedUser user = register("forum-like-user", "password123", "Like User");
        String postId = createPost(user, "Like target", "Like content");

        mockMvc.perform(get("/api/posts").param("page", "0").param("size", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
        mockMvc.perform(get("/api/posts").param("size", "51"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));

        mockMvc.perform(put("/api/posts/{id}/like", postId))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(authenticated(put("/api/posts/{id}/like", postId), user.token()))
                .andExpect(status().isNoContent());
        mockMvc.perform(authenticated(put("/api/posts/{id}/like", postId), user.token()))
                .andExpect(status().isNoContent());
        assertThat(postLikeRepository.findByPostIdIn(List.of(postId))).hasSize(1);
        PostLike duplicate = new PostLike();
        duplicate.setPostId(postId);
        duplicate.setUserId(user.userId());
        duplicate.setCreatedAt(Instant.now());
        assertThatThrownBy(() -> postLikeRepository.insert(duplicate))
                .isInstanceOf(DuplicateKeyException.class);

        mockMvc.perform(authenticated(get("/api/posts/{id}", postId), user.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.authorNickname").value("Like User"))
                .andExpect(jsonPath("$.likeCount").value(1))
                .andExpect(jsonPath("$.commentCount").value(0))
                .andExpect(jsonPath("$.likedByCurrentUser").value(true));

        mockMvc.perform(authenticated(delete("/api/posts/{id}/like", postId), user.token()))
                .andExpect(status().isNoContent());
        mockMvc.perform(authenticated(delete("/api/posts/{id}/like", postId), user.token()))
                .andExpect(status().isNoContent());
        assertThat(postLikeRepository.findByPostIdIn(List.of(postId))).isEmpty();
    }

    @Test
    void supportsCommentsRepliesOwnershipAndPostCascadeCleanup() throws Exception {
        AuthenticatedUser author = register("comment-author", "password123", "Comment Author");
        AuthenticatedUser other = register("comment-other", "password123", "Comment Other");
        String postId = createPost(author, "Discuss", "Comment here");
        String anotherPostId = createPost(author, "Other", "Other post");

        MvcResult commentResult = mockMvc.perform(authenticated(
                        post("/api/posts/{id}/comments", postId), other.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"First comment\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.authorNickname").value("Comment Other"))
                .andReturn();
        String commentId = objectMapper.readTree(commentResult.getResponse().getContentAsByteArray())
                .path("id").asText();

        mockMvc.perform(authenticated(post("/api/posts/{id}/comments", postId), author.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"content":"Reply","replyToCommentId":"%s"}
                                """.formatted(commentId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.replyToNickname").value("Comment Other"));
        mockMvc.perform(authenticated(post("/api/posts/{id}/comments", anotherPostId), author.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"content":"Wrong post","replyToCommentId":"%s"}
                                """.formatted(commentId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REPLY_TARGET"));

        mockMvc.perform(get("/api/posts/{id}/comments", postId).param("page", "0").param("size", "30"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2));
        mockMvc.perform(authenticated(delete("/api/posts/{postId}/comments/{commentId}",
                        postId, commentId), author.token()))
                .andExpect(status().isForbidden());
        mockMvc.perform(authenticated(delete("/api/posts/{postId}/comments/{commentId}",
                        postId, commentId), other.token()))
                .andExpect(status().isNoContent());

        mockMvc.perform(authenticated(put("/api/posts/{id}/like", postId), other.token()))
                .andExpect(status().isNoContent());
        mockMvc.perform(authenticated(delete("/api/posts/{id}", postId), author.token()))
                .andExpect(status().isNoContent());
        assertThat(commentRepository.findByPostIdIn(List.of(postId))).isEmpty();
        assertThat(postLikeRepository.findByPostIdIn(List.of(postId))).isEmpty();
        mockMvc.perform(get("/api/posts/{id}", postId))
                .andExpect(status().isNotFound());
    }

    @Test
    void returnsStableBusinessValidationAndBuildInfoContracts() throws Exception {
        AuthenticatedUser user = register("error-contract-user", "password123", "Error Contract User");

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"error-contract-user","password":"password123",
                                 "nickname":"Error Contract User"}
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("USERNAME_EXISTS"))
                .andExpect(jsonPath("$.message").isString())
                .andExpect(jsonPath("$.fieldErrors").isMap());

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"error-contract-user","password":"wrong-password"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"\",\"password\":\"short\",\"nickname\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.fieldErrors.username").exists())
                .andExpect(jsonPath("$.fieldErrors.password").exists())
                .andExpect(jsonPath("$.fieldErrors.nickname").exists());

        String missingUserToken = tokenForSubject("99999999", Instant.now().minusSeconds(1),
                Instant.now().plusSeconds(300));
        mockMvc.perform(authenticated(get("/api/users/{id}", 99999999L), missingUserToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("USER_NOT_FOUND"));

        mockMvc.perform(get("/actuator/info"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.build.version").isString())
                .andExpect(jsonPath("$.build.time").isString())
                .andExpect(jsonPath("$.build.commit").isString())
                .andExpect(jsonPath("$.build.name").value("engineering-acceptance-backend"));
    }

    @Test
    void concurrentRegistrationReturnsOneSuccessAndOneUsernameConflict() throws Exception {
        String username = "concurrent-registration-user";
        CountDownLatch bothFastPathChecks = new CountDownLatch(2);
        doAnswer(invocation -> {
            bothFastPathChecks.countDown();
            if (!bothFastPathChecks.await(10, TimeUnit.SECONDS)) {
                throw new IllegalStateException("Concurrent registration did not reach the fast path");
            }
            return false;
        }).when(userRepository).existsByUsername(username);

        CountDownLatch start = new CountDownLatch(1);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        try {
            Future<MockHttpServletResponse> first = executor.submit(() -> registerConcurrently(username, start));
            Future<MockHttpServletResponse> second = executor.submit(() -> registerConcurrently(username, start));
            start.countDown();

            List<MockHttpServletResponse> responses = List.of(
                    first.get(30, TimeUnit.SECONDS), second.get(30, TimeUnit.SECONDS));
            assertThat(responses).extracting(MockHttpServletResponse::getStatus)
                    .containsExactlyInAnyOrder(200, 409);
            MockHttpServletResponse conflict = responses.stream()
                    .filter(response -> response.getStatus() == 409)
                    .findFirst()
                    .orElseThrow();
            assertThat(conflict.getContentAsString()).contains("\"code\":\"USERNAME_EXISTS\"");
            assertThat(userRepository.findAll().stream()
                    .filter(candidate -> username.equals(candidate.getUsername())))
                    .hasSize(1);
        } finally {
            executor.shutdownNow();
        }
    }

    private AuthenticatedUser register(String username, String password, String nickname) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"%s","password":"%s","nickname":"%s"}
                                """.formatted(username, password, nickname)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.accessToken").isString())
                .andExpect(jsonPath("$.user.passwordHash").doesNotExist())
                .andReturn();
        JsonNode json = objectMapper.readTree(result.getResponse().getContentAsByteArray());
        return new AuthenticatedUser(json.path("user").path("id").asLong(), json.path("accessToken").asText());
    }

    private String createPost(AuthenticatedUser user, String title, String content) throws Exception {
        MvcResult result = mockMvc.perform(authenticated(post("/api/posts"), user.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"%s","content":"%s"}
                                """.formatted(title, content)))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsByteArray()).path("id").asText();
    }

    private MockHttpServletResponse registerConcurrently(String username, CountDownLatch start) throws Exception {
        if (!start.await(10, TimeUnit.SECONDS)) {
            throw new IllegalStateException("Concurrent registration was not started");
        }
        return mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"%s","password":"password123",
                                 "nickname":"Concurrent User"}
                                """.formatted(username)))
                .andReturn()
                .getResponse();
    }

    private static MockHttpServletRequestBuilder authenticated(
            MockHttpServletRequestBuilder request, String token) {
        return request.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
    }

    private static String validProfile(String nickname) {
        return """
                {"nickname":"%s","birthday":"2001-02-03",
                 "school":"Campus Meow","className":"Class 1"}
                """.formatted(nickname);
    }

    private String tokenForSubject(String subject, Instant issuedAt, Instant expiresAt) {
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer("engineering-acceptance-backend")
                .subject(subject)
                .issuedAt(issuedAt)
                .expiresAt(expiresAt)
                .build();
        return jwtEncoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }

    private record AuthenticatedUser(long userId, String token) {
    }
}
