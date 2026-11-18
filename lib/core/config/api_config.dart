import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String? _testOverrideBaseUrl;

  @visibleForTesting
  static void setBaseUrlForTesting(String url) {
    _testOverrideBaseUrl = url;
  }

  static String get baseUrl {
    if (_testOverrideBaseUrl != null && _testOverrideBaseUrl!.isNotEmpty) {
      return _testOverrideBaseUrl!;
    }
    if (_envBaseUrl.isEmpty) {
      throw StateError(
        'FAIL-FAST: Variable API_BASE_URL es requerida y no está configurada. '
        'Defínela en .env.client y ejecuta con --dart-define-from-file=.env.client '
        'o con --dart-define=API_BASE_URL=http://...',
      );
    }
    return _envBaseUrl;
  }

  static const Duration defaultTimeout = Duration(seconds: 10);

  static Map<String, String> authHeaders(String? token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}
