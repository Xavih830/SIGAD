import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _hostWeb = 'http://localhost:8000';
  static const String _hostAndroid = 'http://10.0.2.2:8000';

  static String get baseUrl {
    if (kIsWeb) return _hostWeb;
    return _hostAndroid;
  }

  static const Duration defaultTimeout = Duration(seconds: 10);

  static Map<String, String> authHeaders(String? token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}
