import 'package:http/http.dart' as http;
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/network/api_client.dart';

/// Repositorio canónico para gestión de clientes y OTP.
/// Desacopla la lógica HTTP y deserialización de las vistas de presentación.
class ClientsRepository {
  final ApiClient _client;

  ClientsRepository({ApiClient? client, http.Client? httpClient})
      : _client = client ?? ApiClient(client: httpClient);

  Future<List<ClientModel>> getClients({String? token}) async {
    final list = await _client.getList('/api/v1/clientes', token: token);
    return list.map((item) => ClientModel.fromJson(item)).toList();
  }

  Future<ClientModel> createClient(CreateClientRequest request, {String? token}) async {
    final data = await _client.post(
      '/api/v1/clientes',
      body: request.toJson(),
      token: token,
    );
    return ClientModel.fromJson(data);
  }

  Future<ClientModel> requestOtp(String clientId, {String? token}) async {
    final data = await _client.post(
      '/api/v1/clientes/$clientId/otp',
      token: token,
    );
    return ClientModel.fromJson(data);
  }
}
