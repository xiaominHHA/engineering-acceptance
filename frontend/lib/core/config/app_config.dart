import 'package:flutter/foundation.dart';

class AppConfig {
  static String get apiBaseUrl => resolveApiBaseUrl(
    configuredBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    isWeb: kIsWeb,
    currentBaseUri: Uri.base,
  );

  static String resolveApiBaseUrl({
    required String configuredBaseUrl,
    required bool isWeb,
    required Uri currentBaseUri,
  }) {
    if (configuredBaseUrl.isNotEmpty) return configuredBaseUrl;
    if (isWeb) return currentBaseUri.origin;
    return 'http://10.0.2.2:18080';
  }
}
