import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/constants/domain_status.dart';
import 'package:sigad/core/models/document_model.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/security/file_security_validator.dart';

class DocumentsRepository {
  final ApiClient _client;

  DocumentsRepository({ApiClient? client, http.Client? httpClient})
      : _client = client ?? ApiClient(client: httpClient);

  Future<List<DocumentModel>> getDocuments({String? token}) async {
    final list = await _client.getList(ApiEndpoints.documentos, token: token);
    return list.map((json) => DocumentModel.fromJson(json)).toList();
  }

  Future<DocumentModel> getDocumentById(String documentId, {String? token}) async {
    final json = await _client.getMap(ApiEndpoints.documento(documentId), token: token);
    return DocumentModel.fromJson(json);
  }

  Future<Uint8List> downloadDocumentBytes(String documentId, {String? token}) async {
    return _client.getBytes(
      ApiEndpoints.documentoDescarga(documentId),
      token: token,
    );
  }

  static void validateFileIntegrity(Uint8List bytes, String filename) {
    FileSecurityValidator.validatePreFlight(bytes: bytes, filename: filename);
  }

  Future<DocumentModel> uploadDocument({
    required Uint8List bytes,
    required String filename,
    String? token,
  }) async {
    validateFileIntegrity(bytes, filename);
    final data = await _client.multipart(
      path: ApiEndpoints.documentos,
      bytes: bytes,
      filename: filename,
      token: token,
    );
    return DocumentModel.fromJson(data);
  }

  Future<DocumentModel> confirmRevision({
    required String documentId,
    required Map<String, dynamic> camposCorregidos,
    String? token,
  }) async {
    final data = await _client.patch(
      ApiEndpoints.documentoRevision(documentId),
      body: {
        'campos_extraidos': camposCorregidos,
        'estado_extraccion': ExtractionStatus.completado.value,
      },
      token: token,
    );
    return DocumentModel.fromJson(data);
  }
}
