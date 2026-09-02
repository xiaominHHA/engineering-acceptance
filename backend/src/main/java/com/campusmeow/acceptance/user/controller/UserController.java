package com.campusmeow.acceptance.user.controller;

import jakarta.validation.Valid;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.core.annotation.AuthenticationPrincipal;

import com.campusmeow.acceptance.user.dto.UserResponse;
import com.campusmeow.acceptance.user.dto.UserUpdateRequest;
import com.campusmeow.acceptance.user.service.UserService;
import com.campusmeow.acceptance.common.error.BusinessException;
import com.campusmeow.acceptance.common.error.BusinessException.Code;

@RestController
@RequestMapping("/api/users")
public class UserController {
    private final UserService service;

    public UserController(UserService service) { this.service = service; }

    @GetMapping("/{id}")
    public UserResponse get(@PathVariable Long id, @AuthenticationPrincipal Jwt principal) {
        requireOwner(id, principal);
        return service.get(id);
    }

    @PutMapping("/{id}")
    public UserResponse update(@PathVariable Long id, @Valid @RequestBody UserUpdateRequest request,
            @AuthenticationPrincipal Jwt principal) {
        requireOwner(id, principal);
        return service.update(id, request);
    }

    private static void requireOwner(Long requestedId, Jwt principal) {
        if (!requestedId.toString().equals(principal.getSubject())) {
            throw new BusinessException(Code.ACCESS_DENIED, "Cannot access another user");
        }
    }
}
