import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/models/policy_model.dart';

/// Repositorio canónico para gestión y consulta de pólizas de seguro.
/// Desacopla la lógica HTTP y deserialización de las vistas de presentación.
class PoliciesRepository {
  final http.Client _client;

  PoliciesRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PolicyModel>> getPolicies({String? token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/polizas'),
      headers: ApiConfig.authHeaders(token),
    ).timeout(ApiConfig.defaultTimeout);

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((item) => PolicyModel.fromJson(item))
          .toList();
    }
    throw StateError('Error ${response.statusCode} al obtener pólizas: ${response.body}');
  }

  Future<PolicyModel> createPolicy(PolicyModel policy, {String? token}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/polizas'),
      headers: ApiConfig.authHeaders(token),
      body: jsonEncode(policy.toJson()),
    ).timeout(ApiConfig.defaultTimeout);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PolicyModel.fromJson(data);
    }
    throw StateError('Error ${response.statusCode} al registrar póliza: ${response.body}');
  }
}
