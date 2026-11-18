import 'package:http/http.dart' as http;
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/constants/app_constants.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/core/network/api_client.dart';

class VehiclesRepository {
  final ApiClient _client;

  VehiclesRepository({ApiClient? client, http.Client? httpClient})
      : _client = client ?? ApiClient(client: httpClient);

  Future<List<VehicleModel>> getVehicles({
    int skip = AppConstants.defaultPageSkip,
    int limit = AppConstants.defaultPageLimit,
    String? clientId,
    String? token,
  }) async {
    final list = await _client.getList(
      ApiEndpoints.vehiculosPage(skip: skip, limit: limit, clienteId: clientId),
      token: token,
    );
    return list.map((item) => VehicleModel.fromJson(item)).toList();
  }

  Future<List<VehicleModel>> getVehiclesByClient(String clientId, {String? token}) async {
    return getVehicles(clientId: clientId, token: token);
  }

  Future<VehicleModel> createVehicle(CreateVehicleRequest request, {String? token}) async {
    final response = await _client.post(
      ApiEndpoints.vehiculos,
      body: request.toJson(),
      token: token,
    );
    return VehicleModel.fromJson(response);
  }

  Future<VehicleModel> updateVehicle(
    String id,
    UpdateVehicleRequest request, {
    String? token,
  }) async {
    final response = await _client.patch(
      ApiEndpoints.vehiculo(id),
      body: request.toJson(),
      token: token,
    );
    return VehicleModel.fromJson(response);
  }
}
