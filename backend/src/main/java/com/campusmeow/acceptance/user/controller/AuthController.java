package com.campusmeow.acceptance.user.controller;

import jakarta.validation.Valid;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.campusmeow.acceptance.user.dto.LoginRequest;
import com.campusmeow.acceptance.user.dto.RegisterRequest;
import com.campusmeow.acceptance.user.dto.UserResponse;
import com.campusmeow.acceptance.user.service.UserService;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final UserService service;

    public AuthController(UserService service) { this.service = service; }

    @PostMapping("/register")
    public UserResponse register(@Valid @RequestBody RegisterRequest request) {
        return service.register(request);
    }

    @PostMapping("/login")
    public UserResponse login(@Valid @RequestBody LoginRequest request) {
        return service.login(request);
    }
}
