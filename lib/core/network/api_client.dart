import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/constants/app_constants.dart';
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
    } catch (_) {
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
    final response = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(token, headers),
    ).timeout(timeout ?? AppConstants.apiDefaultTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    }
    _handleError(response);
  }

  Future<Map<String, dynamic>> getMap(
    String path, {
    String? token,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(token, headers),
    ).timeout(timeout ?? AppConstants.apiDefaultTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    }
    _handleError(response);
  }

  Future<Uint8List> getBytes(
    String path, {
    String? token,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(token, headers),
    ).timeout(timeout ?? AppConstants.apiDefaultTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    _handleError(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    String? token,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(token, headers),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(timeout ?? AppConstants.apiDefaultTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    }
    _handleError(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
    String? token,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: _buildHeaders(token, headers),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(timeout ?? AppConstants.apiDefaultTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    }
    _handleError(response);
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
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    final resolvedToken = _resolveToken(token);
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
    } else {
      mediaType = MediaType('image', 'jpeg');
    }

    request.files.add(http.MultipartFile.fromBytes(
      fieldName,
      bytes,
      filename: filename,
      contentType: mediaType,
    ));

    final streamResponse = await _client.send(request).timeout(timeout);
    final responseBody = await streamResponse.stream.bytesToString();

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
    } catch (_) {
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
