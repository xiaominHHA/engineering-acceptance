package com.campusmeow.acceptance.common.error;

import java.util.Map;

public record ApiError(String code, String message, Map<String, String> fieldErrors) {
}
