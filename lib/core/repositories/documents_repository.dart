import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:sigad/core/network/api_client.dart';

/// Repositorio canónico para el ciclo de vida de documentos OCR (HU-06).
class DocumentsRepository {
  final ApiClient _client;

  DocumentsRepository({ApiClient? client, http.Client? httpClient})
      : _client = client ?? ApiClient(client: httpClient);

  Future<List<Map<String, dynamic>>> getDocuments({String? token}) async {
    return _client.getList('/api/v1/documentos', token: token);
  }

  Future<Map<String, dynamic>> getDocumentById(String documentId, {String? token}) async {
    return _client.getMap('/api/v1/documentos/$documentId', token: token);
  }

  Future<Map<String, dynamic>> uploadDocument({
    required Uint8List bytes,
    required String filename,
    String? token,
  }) async {
    return _client.multipart(
      path: '/api/v1/documentos',
      bytes: bytes,
      filename: filename,
      token: token,
    );
  }

  Future<Map<String, dynamic>> confirmRevision({
    required String documentId,
    required Map<String, dynamic> camposCorregidos,
    String? token,
  }) async {
    return _client.patch(
      '/api/v1/documentos/$documentId/revision',
      body: {
        'campos_extraidos': camposCorregidos,
        'estado_extraccion': 'completado',
      },
      token: token,
    );
  }
}
