import '../network/api_exception.dart';

enum AppFailureType {
  validation,
  invalidCredentials,
  usernameExists,
  sessionExpired,
  forbidden,
  notFound,
  featureUnavailable,
  network,
  server,
  unknown,
}

class AppFailure implements Exception {
  const AppFailure(this.type, {this.message, this.fieldErrors = const {}});

  final AppFailureType type;
  final String? message;
  final Map<String, String> fieldErrors;

  factory AppFailure.fromApiException(
    ApiException exception, {
    AppFailureType? Function(int statusCode)? legacyStatusFallback,
  }) {
    if (exception.kind == ApiExceptionKind.network) {
      return const AppFailure(AppFailureType.network);
    }
    final code = exception.code?.trim();
    final type = code != null && code.isNotEmpty
        ? switch (code) {
            'VALIDATION_FAILED' => AppFailureType.validation,
            'INVALID_CREDENTIALS' => AppFailureType.invalidCredentials,
            'USERNAME_EXISTS' => AppFailureType.usernameExists,
            'USER_NOT_FOUND' => AppFailureType.notFound,
            'POST_NOT_FOUND' => AppFailureType.notFound,
            'AUTHENTICATION_REQUIRED' ||
            'TOKEN_INVALID_OR_EXPIRED' => AppFailureType.sessionExpired,
            'ACCESS_DENIED' => AppFailureType.forbidden,
            'INTERNAL_ERROR' => AppFailureType.server,
            _ => AppFailureType.unknown,
          }
        : legacyStatusFallback?.call(exception.statusCode ?? 0) ??
              AppFailureType.unknown;
    return AppFailure(
      type,
      message: exception.message,
      fieldErrors: exception.fieldErrors,
    );
  }
}
