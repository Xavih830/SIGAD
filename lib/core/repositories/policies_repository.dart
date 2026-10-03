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
    String vehicleId = policy.vehicleId;

    if (vehicleId.isEmpty && policy.vehicle != null) {
      final plate = policy.vehicle!.plate.toUpperCase();
      try {
        final vehicles = await _client.getList('/api/v1/vehiculos', token: token);
        final match = vehicles.firstWhere(
          (v) => (v['placa'] as String).toUpperCase() == plate,
          orElse: () => {},
        );
        if (match.isNotEmpty && match['id'] != null) {
          vehicleId = match['id'] as String;
        } else {
          final createdVeh = await _client.post(
            '/api/v1/vehiculos',
            body: {
              'placa': plate,
              'marca': policy.vehicle!.brand,
              'modelo': policy.vehicle!.model,
              'anio': policy.vehicle!.year,
              'cliente_id': policy.clientId,
            },
            token: token,
          );
          vehicleId = createdVeh['id'] as String;
        }
      } catch (_) {
        // En caso de error de búsqueda, se intenta con el ID original
      }
    }

    final payload = policy.toCreatePayloadJson();
    if (vehicleId.isNotEmpty) {
      payload['vehiculo_id'] = vehicleId;
    }

    final data = await _client.post(
      '/api/v1/polizas',
      body: payload,
      token: token,
    );
    return PolicyModel.fromJson(data);
  }
}
