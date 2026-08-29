package com.campusmeow.acceptance.user.service;

import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import com.campusmeow.acceptance.user.dto.LoginRequest;
import com.campusmeow.acceptance.user.dto.RegisterRequest;
import com.campusmeow.acceptance.user.dto.UserResponse;
import com.campusmeow.acceptance.user.dto.UserUpdateRequest;
import com.campusmeow.acceptance.user.entity.User;
import com.campusmeow.acceptance.user.repository.UserRepository;

@Service
public class UserService {
    private final UserRepository repository;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository repository, PasswordEncoder passwordEncoder) {
        this.repository = repository;
        this.passwordEncoder = passwordEncoder;
    }

    public UserResponse register(RegisterRequest request) {
        if (repository.existsByUsername(request.username())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "username already exists");
        }
        User user = new User();
        user.setUsername(request.username());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setNickname(request.nickname());
        return UserResponse.from(repository.save(user));
    }

    public UserResponse login(LoginRequest request) {
        User user = repository.findByUsername(request.username())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "invalid credentials"));
        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "invalid credentials");
        }
        return UserResponse.from(user);
    }

    public UserResponse get(Long id) {
        return UserResponse.from(find(id));
    }

    public UserResponse update(Long id, UserUpdateRequest request) {
        User user = find(id);
        user.setNickname(request.nickname());
        user.setBirthday(request.birthday());
        user.setSchool(request.school());
        user.setClassName(request.className());
        return UserResponse.from(repository.save(user));
    }

    private User find(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "user not found"));
    }
}
