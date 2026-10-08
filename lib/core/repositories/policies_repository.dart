import 'package:http/http.dart' as http;
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/constants/app_constants.dart';
import 'package:sigad/core/models/deductible_model.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/core/network/api_client.dart';

/// Repositorio canónico para gestión y consulta de pólizas de seguro.
/// Desacopla la lógica HTTP y deserialización de las vistas de presentación.
class PoliciesRepository {
  final ApiClient _client;

  PoliciesRepository({ApiClient? client, http.Client? httpClient})
      : _client = client ?? ApiClient(client: httpClient);

  Future<List<PolicyModel>> getPolicies({
    int skip = AppConstants.defaultPageSkip,
    int limit = AppConstants.defaultPageLimit,
    String? token,
  }) async {
    final list = await _client.getList(
      ApiEndpoints.polizas(skip: skip, limit: limit),
      token: token,
    );
    return list.map((item) => PolicyModel.fromJson(item)).toList();
  }

  Future<PolicyModel> createPolicy(CreatePolicyRequest request, {String? token}) async {
    String vehicleId = request.vehicleId ?? '';

    if (vehicleId.isEmpty && request.vehicle != null) {
      final plate = request.vehicle!.plate.toUpperCase();
      final vehicles = await _client.getList(ApiEndpoints.vehiculos, token: token);
      final match = vehicles.firstWhere(
        (v) => (v['placa'] as String).toUpperCase() == plate,
        orElse: () => {},
      );
      if (match.isNotEmpty && match['id'] != null) {
        vehicleId = match['id'] as String;
      } else {
        final createdVeh = await _client.post(
          ApiEndpoints.vehiculos,
          body: {
            'placa': plate,
            'marca': request.vehicle!.brand,
            'modelo': request.vehicle!.model,
            'anio': request.vehicle!.year,
            'cliente_id': request.clientId,
          },
          token: token,
        );
        vehicleId = createdVeh['id'] as String;
      }
    }

    if (vehicleId.isEmpty) {
      throw StateError('FAIL-FAST: No se pudo resolver ni registrar el vehículo asociado a la póliza.');
    }

    final payload = request.toCreatePayloadJson(resolvedVehicleId: vehicleId);

    final data = await _client.post(
      ApiEndpoints.polizasBase,
      body: payload,
      token: token,
    );
    return PolicyModel.fromJson(data);
  }

  Future<PolicyModel> getPolicy(String id, {String? token}) async {
    final data = await _client.getMap(
      ApiEndpoints.poliza(id),
      token: token,
    );
    return PolicyModel.fromJson(data);
  }

  Future<PolicyModel> updatePolicyStatus(String id, String nuevoEstado, {String? token}) async {
    final data = await _client.patch(
      ApiEndpoints.polizaEstado(id),
      body: {'estado': nuevoEstado},
      token: token,
    );
    return PolicyModel.fromJson(data);
  }

  Future<List<DeductibleModel>> getPolicyDeductibles(String policyId, {String? token}) async {
    final list = await _client.getList(
      ApiEndpoints.polizaDeducibles(policyId),
      token: token,
    );
    return list.map((item) => DeductibleModel.fromJson(item)).toList();
  }

  Future<VehicleModel> getVehicleById(String vehicleId, {String? token}) async {
    final data = await _client.getMap(
      ApiEndpoints.vehiculo(vehicleId),
      token: token,
    );
    return VehicleModel.fromJson(data);
  }
}
