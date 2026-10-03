import 'package:http/http.dart' as http;
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/network/api_client.dart';

/// Repositorio canónico para gestión y consulta de pólizas de seguro.
/// Desacopla la lógica HTTP y deserialización de las vistas de presentación.
class PoliciesRepository {
  final ApiClient _client;

  PoliciesRepository({ApiClient? client, http.Client? httpClient})
      : _client = client ?? ApiClient(client: httpClient);

  Future<List<PolicyModel>> getPolicies({String? token}) async {
    final list = await _client.getList('/api/v1/polizas', token: token);
    return list.map((item) => PolicyModel.fromJson(item)).toList();
  }

  Future<PolicyModel> createPolicy(PolicyModel policy, {String? token}) async {
    final data = await _client.post(
      '/api/v1/polizas',
      body: policy.toCreatePayloadJson(),
      token: token,
    );
    return PolicyModel.fromJson(data);
  }
}
