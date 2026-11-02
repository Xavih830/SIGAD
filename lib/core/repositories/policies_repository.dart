import 'package:http/http.dart' as http;
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/constants/app_constants.dart';
import 'package:sigad/core/models/deductible_model.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/repositories/vehicles_repository.dart';

class PoliciesRepository {
  final ApiClient _client;
  final VehiclesRepository _vehiclesRepository;

  PoliciesRepository({
    ApiClient? client,
    http.Client? httpClient,
    VehiclesRepository? vehiclesRepository,
  })  : _client = client ?? ApiClient(client: httpClient),
        _vehiclesRepository = vehiclesRepository ??
            VehiclesRepository(client: client ?? ApiClient(client: httpClient));

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
      final vehicles = await _vehiclesRepository.getVehicles(token: token);
      final match = vehicles.where((v) => v.plate.toUpperCase() == plate).firstOrNull;
      if (match != null && match.id != null) {
        vehicleId = match.id!;
      } else {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final createdVeh = await _vehiclesRepository.createVehicle(
          CreateVehicleRequest(
            plate: plate,
            brand: request.vehicle!.brand,
            model: request.vehicle!.model,
            year: request.vehicle!.year,
            motor: request.vehicle!.motor ?? 'MOT-$nowMs',
            chasis: request.vehicle!.chasis ??
                '1HGCR2F83HA${nowMs.toString().padLeft(6, '0').substring(0, 6)}',
            color: request.vehicle!.color ?? 'BLANCO',
            clientId: request.clientId,
          ),
          token: token,
        );
        vehicleId = createdVeh.id!;
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
