package com.campusmeow.acceptance.common.error;

public final class BusinessException extends RuntimeException {

    public enum Code {
        USERNAME_EXISTS,
        INVALID_CREDENTIALS,
        USER_NOT_FOUND,
        ACCESS_DENIED
    }

    private final Code code;

    public BusinessException(Code code, String message) {
        super(message);
        this.code = code;
    }

    public Code getCode() {
        return code;
    }
}
