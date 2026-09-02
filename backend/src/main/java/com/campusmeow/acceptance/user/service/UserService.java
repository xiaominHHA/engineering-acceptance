package com.campusmeow.acceptance.user.service;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.hibernate.exception.ConstraintViolationException;
import org.hibernate.exception.ConstraintViolationException.ConstraintKind;

import com.campusmeow.acceptance.common.error.BusinessException;
import com.campusmeow.acceptance.common.error.BusinessException.Code;
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
            throw new BusinessException(Code.USERNAME_EXISTS, "Username already exists");
        }
        User user = new User();
        user.setUsername(request.username());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setNickname(request.nickname());
        try {
            return UserResponse.from(repository.saveAndFlush(user));
        } catch (DataIntegrityViolationException exception) {
            if (isUsernameUniqueViolation(exception)) {
                throw new BusinessException(Code.USERNAME_EXISTS, "Username already exists");
            }
            throw exception;
        }
    }

    public UserResponse login(LoginRequest request) {
        User user = repository.findByUsername(request.username())
                .orElseThrow(() -> new BusinessException(Code.INVALID_CREDENTIALS, "Invalid credentials"));
        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BusinessException(Code.INVALID_CREDENTIALS, "Invalid credentials");
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
                .orElseThrow(() -> new BusinessException(Code.USER_NOT_FOUND, "User not found"));
    }

    private static boolean isUsernameUniqueViolation(DataIntegrityViolationException exception) {
        Throwable cause = exception;
        while (cause != null) {
            if (cause instanceof ConstraintViolationException violation
                    && violation.getKind() == ConstraintKind.UNIQUE
                    && isUsernameConstraint(violation.getConstraintName())) {
                return true;
            }
            cause = cause.getCause();
        }
        return false;
    }

    private static boolean isUsernameConstraint(String constraintName) {
        if (constraintName == null) {
            return false;
        }
        int qualifier = constraintName.lastIndexOf('.');
        String unqualifiedName = constraintName.substring(qualifier + 1);
        return "username".equalsIgnoreCase(unqualifiedName);
    }
}
