import 'package:http/http.dart' as http;
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/models/policy_schema_model.dart';
import 'package:sigad/core/network/api_client.dart';

class PolicySchemasRepository {
  final ApiClient _client;

  PolicySchemasRepository({ApiClient? client, http.Client? httpClient})
      : _client = client ?? ApiClient(client: httpClient);

  Future<List<PolicySchemaListItemModel>> getSchemas({String? token}) async {
    final list = await _client.getList(ApiEndpoints.esquemasPoliza, token: token);
    return list.map((json) => PolicySchemaListItemModel.fromJson(json)).toList();
  }

  Future<PolicySchemaModel> getSchemaById(String id, {String? token}) async {
    final json = await _client.getMap(ApiEndpoints.esquemaPoliza(id), token: token);
    return PolicySchemaModel.fromJson(json);
  }

  Future<PolicySchemaModel> createSchema(CreatePolicySchemaRequest request, {String? token}) async {
    final json = await _client.post(
      ApiEndpoints.esquemasPoliza,
      body: request.toJson(),
      token: token,
    );
    return PolicySchemaModel.fromJson(json);
  }

  Future<PolicySchemaModel> activateSchema(String id, {String? token}) async {
    final json = await _client.patch(
      ApiEndpoints.esquemaPolizaActivar(id),
      token: token,
    );
    return PolicySchemaModel.fromJson(json);
  }
}
