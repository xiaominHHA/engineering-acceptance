package com.campusmeow.acceptance.user.service;

import org.springframework.stereotype.Service;

import com.campusmeow.acceptance.security.TokenService;
import com.campusmeow.acceptance.security.TokenService.IssuedToken;
import com.campusmeow.acceptance.user.dto.AuthResponse;
import com.campusmeow.acceptance.user.dto.LoginRequest;
import com.campusmeow.acceptance.user.dto.RegisterRequest;
import com.campusmeow.acceptance.user.dto.UserResponse;

@Service
public class AuthService {

    private final UserService userService;
    private final TokenService tokenService;

    public AuthService(UserService userService, TokenService tokenService) {
        this.userService = userService;
        this.tokenService = tokenService;
    }

    public AuthResponse register(RegisterRequest request) {
        return authenticated(userService.register(request));
    }

    public AuthResponse login(LoginRequest request) {
        return authenticated(userService.login(request));
    }

    private AuthResponse authenticated(UserResponse user) {
        IssuedToken token = tokenService.issue(user.id());
        return new AuthResponse("Bearer", token.value(), token.expiresAt(), user);
    }
}
