import 'package:http/http.dart' as http;
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/network/api_client.dart';

class ClientsRepository {
  final ApiClient _client;

  ClientsRepository({ApiClient? client, http.Client? httpClient})
      : _client = client ?? ApiClient(client: httpClient);

  Future<PaginatedClients> getClients({
    String? query,
    int skip = 0,
    int limit = 10,
    String? token,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    };
    final uri = Uri(path: ApiEndpoints.clientes, queryParameters: queryParams);
    final data = await _client.getMap(uri.toString(), token: token);
    return PaginatedClients.fromJson(data);
  }

  Future<ClientModel> getClientById(String clientId, {String? token}) async {
    final data = await _client.getMap(
      ApiEndpoints.cliente(clientId),
      token: token,
    );
    return ClientModel.fromJson(data);
  }

  Future<ClientModel> createClient(CreateClientRequest request, {String? token}) async {
    final data = await _client.post(
      ApiEndpoints.clientes,
      body: request.toJson(),
      token: token,
    );
    return ClientModel.fromJson(data);
  }

  Future<ClientModel> updateClient(
    String clientId,
    UpdateClientRequest request, {
    String? token,
  }) async {
    final data = await _client.patch(
      ApiEndpoints.cliente(clientId),
      body: request.toJson(),
      token: token,
    );
    return ClientModel.fromJson(data);
  }

  Future<void> deleteClient(String clientId, {String? token}) async {
    await _client.delete(
      ApiEndpoints.cliente(clientId),
      token: token,
    );
  }

  Future<ClientModel> requestOtp(String clientId, {String? token}) async {
    final data = await _client.post(
      ApiEndpoints.clienteOtp(clientId),
      token: token,
    );
    return ClientModel.fromJson(data);
  }
}

