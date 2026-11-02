import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/constants/app_constants.dart';
import 'package:sigad/core/network/session_events.dart';
import 'package:sigad/core/network/token_provider.dart';
import 'package:sigad/core/services/session_vault.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}

class ApiForbiddenException extends ApiException {
  const ApiForbiddenException({
    required super.statusCode,
    required super.message,
  });
}

class ApiClient {
  final http.Client _client;
  final String baseUrl;
  final TokenProvider? tokenProvider;
  final void Function()? onUnauthorized;

  static Future<bool>? _refreshInFlight;

  ApiClient({
    http.Client? client,
    String? baseUrl,
    this.tokenProvider,
    this.onUnauthorized,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfig.baseUrl;

  String? _resolveToken(String? explicitToken) {
    if (explicitToken != null && explicitToken.isNotEmpty) {
      return explicitToken;
    }
    if (tokenProvider != null) {
      return tokenProvider!();
    }
    return SessionVault.currentAccessToken;
  }

  Map<String, String> _buildHeaders(String? token, Map<String, String>? extraHeaders) {
    final resolvedToken = _resolveToken(token);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (resolvedToken != null && resolvedToken.isNotEmpty)
        'Authorization': 'Bearer $resolvedToken',
    };
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  bool _isAuthEndpoint(String path) {
    return path.contains(ApiEndpoints.authLogin) ||
        path.contains(ApiEndpoints.authRefresh) ||
        path.contains(ApiEndpoints.authLogout) ||
        path.contains(ApiEndpoints.authVinculacion);
  }

  Future<bool> _tryRefresh() async {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }

    final future = _doRefresh();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await SessionVault.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse('$baseUrl${ApiEndpoints.authRefresh}');
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(AppConstants.apiDefaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final newAccess = data['access_token'] as String;
        final newRefresh = data['refresh_token'] as String;
        await SessionVault.updateTokens(access: newAccess, refresh: newRefresh);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiClient] Fallo al refrescar token: $e');
      return false;
    }
  }

  Future<http.Response> _send({
    required String path,
    required Future<http.Response> Function(Map<String, String> headers) execute,
    String? token,
    Map<String, String>? headers,
  }) async {
    final initialHeaders = _buildHeaders(token, headers);
    final response = await execute(initialHeaders);

    if (response.statusCode == 401 && !_isAuthEndpoint(path)) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retryHeaders = _buildHeaders(null, headers);
        final retryResponse = await execute(retryHeaders);
        if (retryResponse.statusCode >= 200 && retryResponse.statusCode < 300) {
          return retryResponse;
        }
        _handleError(retryResponse);
      } else {
        await SessionVault.clearSession();
        SessionEvents.notifyExpired();
        onUnauthorized?.call();
        throw const ApiException(
          statusCode: 401,
          message: 'Su sesión ha expirado. Inicie sesión nuevamente.',
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    _handleError(response);
  }

  Never _handleError(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    String detail;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded.containsKey('detail')) {
        detail = decoded['detail'].toString();
      } else {
        detail = decoded.toString();
      }
    } on FormatException catch (e) {
      debugPrint('[ApiClient] Respuesta no es JSON válido: $e');
      detail = response.body;
    }
    if (response.statusCode == 403) {
      throw ApiForbiddenException(
        statusCode: 403,
        message: 'Acceso denegado (403): $detail',
      );
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Error ${response.statusCode}: $detail',
    );
  }

  Future<List<Map<String, dynamic>>> getList(
    String path, {
    String? token,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await _send(
      path: path,
      token: token,
      headers: headers,
      execute: (h) => _client.get(
        Uri.parse('$baseUrl$path'),
        headers: h,
      ).timeout(timeout ?? AppConstants.apiDefaultTimeout),
    );

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is List) {
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Respuesta inesperada: se esperaba una lista JSON pero se recibió ${decoded.runtimeType}',
    );
  }

  Future<Map<String, dynamic>> getMap(
    String path, {
    String? token,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await _send(
      path: path,
      token: token,
      headers: headers,
      execute: (h) => _client.get(
        Uri.parse('$baseUrl$path'),
        headers: h,
      ).timeout(timeout ?? AppConstants.apiDefaultTimeout),
    );

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Uint8List> getBytes(
    String path, {
    String? token,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await _send(
      path: path,
      token: token,
      headers: headers,
      execute: (h) => _client.get(
        Uri.parse('$baseUrl$path'),
        headers: h,
      ).timeout(timeout ?? AppConstants.apiDefaultTimeout),
    );

    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    String? token,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await _send(
      path: path,
      token: token,
      headers: headers,
      execute: (h) => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: h,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(timeout ?? AppConstants.apiDefaultTimeout),
    );

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Respuesta inesperada: se esperaba un objeto JSON pero se recibió ${decoded.runtimeType}',
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
    String? token,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await _send(
      path: path,
      token: token,
      headers: headers,
      execute: (h) => _client.patch(
        Uri.parse('$baseUrl$path'),
        headers: h,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(timeout ?? AppConstants.apiDefaultTimeout),
    );

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Respuesta inesperada: se esperaba un objeto JSON pero se recibió ${decoded.runtimeType}',
    );
  }

  Future<void> delete(
    String path, {
    String? token,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    await _send(
      path: path,
      token: token,
      headers: headers,
      execute: (h) => _client.delete(
        Uri.parse('$baseUrl$path'),
        headers: h,
      ).timeout(timeout ?? AppConstants.apiDefaultTimeout),
    );
  }

  Future<Map<String, dynamic>> multipart({
    required String path,
    required Uint8List bytes,
    required String filename,
    String fieldName = 'file',
    String? token,
    Map<String, String>? fields,
    Duration timeout = AppConstants.apiUploadTimeout,
  }) async {
    Future<http.StreamedResponse> sendMultipart(String? currentToken) {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      final resolvedToken = _resolveToken(currentToken);
      if (resolvedToken != null && resolvedToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $resolvedToken';
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }

      final ext = filename.toLowerCase().split('.').last;
      MediaType mediaType;
      if (ext == 'pdf') {
        mediaType = MediaType('application', 'pdf');
      } else if (ext == 'png') {
        mediaType = MediaType('image', 'png');
      } else if (ext == 'tif' || ext == 'tiff') {
        mediaType = MediaType('image', 'tiff');
      } else if (ext == 'jpg' || ext == 'jpeg') {
        mediaType = MediaType('image', 'jpeg');
      } else {
        throw ArgumentError('Extensión no permitida: .$ext. Extensiones válidas: ${AppConstants.permittedExtensions.join(', ')}');
      }

      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
        contentType: mediaType,
      ));

      return _client.send(request).timeout(timeout);
    }

    var streamResponse = await sendMultipart(token);
    var responseBody = await streamResponse.stream.bytesToString();

    if (streamResponse.statusCode == 401 && !_isAuthEndpoint(path)) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        streamResponse = await sendMultipart(null);
        responseBody = await streamResponse.stream.bytesToString();
      } else {
        await SessionVault.clearSession();
        SessionEvents.notifyExpired();
        onUnauthorized?.call();
        throw const ApiException(
          statusCode: 401,
          message: 'Su sesión ha expirado. Inicie sesión nuevamente.',
        );
      }
    }

    if (streamResponse.statusCode >= 200 && streamResponse.statusCode < 300) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    }

    if (streamResponse.statusCode == 401) {
      onUnauthorized?.call();
    }

    String detail;
    try {
      final decoded = jsonDecode(responseBody);
      detail = decoded is Map && decoded.containsKey('detail')
          ? decoded['detail'].toString()
          : responseBody;
    } on FormatException catch (e) {
      debugPrint('[ApiClient] Respuesta multipart no es JSON válido: $e');
      detail = responseBody;
    }

    if (streamResponse.statusCode == 403) {
      throw ApiForbiddenException(
        statusCode: 403,
        message: 'Acceso denegado (403): $detail',
      );
    }

    throw ApiException(
      statusCode: streamResponse.statusCode,
      message: 'Error ${streamResponse.statusCode}: $detail',
    );
  }

  void close() {
    _client.close();
  }
}
