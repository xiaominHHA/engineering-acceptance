enum ApiExceptionKind { http, network }

class ApiException implements Exception {
  const ApiException.http({
    required this.statusCode,
    this.code,
    this.message,
    this.fieldErrors = const {},
  }) : kind = ApiExceptionKind.http;

  const ApiException.network()
    : kind = ApiExceptionKind.network,
      statusCode = null,
      code = null,
      message = null,
      fieldErrors = const {};

  final ApiExceptionKind kind;
  final int? statusCode;
  final String? code;
  final String? message;
  final Map<String, String> fieldErrors;
}
