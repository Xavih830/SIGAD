import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/models/extraction_schema_model.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/security/file_security_validator.dart';

class ExtractionSchemasRepository {
  final ApiClient _client;

  ExtractionSchemasRepository({ApiClient? client, http.Client? httpClient})
      : _client = client ?? ApiClient(client: httpClient);

  Future<List<ExtractionSchemaListItemModel>> getSchemas({String? token}) async {
    final list = await _client.getList(ApiEndpoints.esquemas, token: token);
    return list.map((json) => ExtractionSchemaListItemModel.fromJson(json)).toList();
  }

  Future<ExtractionSchemaModel> getSchemaById(String id, {String? token}) async {
    final json = await _client.getMap(ApiEndpoints.esquema(id), token: token);
    return ExtractionSchemaModel.fromJson(json);
  }

  Future<ExtractionSchemaModel> createSchema(CreateSchemaRequest request, {String? token}) async {
    final json = await _client.post(
      ApiEndpoints.esquemas,
      body: request.toJson(),
      token: token,
    );
    return ExtractionSchemaModel.fromJson(json);
  }

  Future<ExtractionSchemaModel> activateSchema(String id, {String? token}) async {
    final json = await _client.patch(
      ApiEndpoints.esquemaActivar(id),
      token: token,
    );
    return ExtractionSchemaModel.fromJson(json);
  }

  Future<TestSchemaResultModel> testSchema(
    String id, {
    required Uint8List bytes,
    required String filename,
    String? token,
  }) async {
    FileSecurityValidator.validatePreFlight(bytes: bytes, filename: filename);
    final json = await _client.multipart(
      path: ApiEndpoints.esquemaProbar(id),
      bytes: bytes,
      filename: filename,
      token: token,
    );
    return TestSchemaResultModel.fromJson(json);
  }
}
