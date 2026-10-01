import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/models/client_model.dart';

/// Repositorio canónico para gestión de clientes y OTP.
/// Desacopla la lógica HTTP y deserialización de las vistas de presentación.
class ClientsRepository {
  final http.Client _client;

  ClientsRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<List<ClientModel>> getClients({String? token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/clientes'),
      headers: ApiConfig.authHeaders(token),
    ).timeout(ApiConfig.defaultTimeout);

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((item) => ClientModel.fromJson(item))
          .toList();
    }
    throw StateError('Error ${response.statusCode} al obtener clientes: ${response.body}');
  }

  Future<ClientModel> createClient(CreateClientRequest request, {String? token}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/clientes'),
      headers: ApiConfig.authHeaders(token),
      body: jsonEncode(request.toJson()),
    ).timeout(ApiConfig.defaultTimeout);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ClientModel.fromJson(data);
    }
    throw StateError('Error ${response.statusCode} al crear cliente: ${response.body}');
  }

  Future<ClientModel> requestOtp(String clientId, {String? token}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/clientes/$clientId/otp'),
      headers: ApiConfig.authHeaders(token),
    ).timeout(ApiConfig.defaultTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ClientModel.fromJson(data);
    }
    throw StateError('Error ${response.statusCode} al generar código OTP: ${response.body}');
  }
}
