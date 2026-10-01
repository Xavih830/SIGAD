import 'package:http/http.dart' as http;
import 'package:sigad/core/models/catalog_model.dart';
import 'package:sigad/core/network/api_client.dart';

/// Repositorio canónico para consulta de catálogos (talleres y asistencias viales).
class CatalogRepository {
  final ApiClient _client;

  CatalogRepository({ApiClient? client, http.Client? httpClient})
      : _client = client ?? ApiClient(client: httpClient);

  Future<List<WorkshopModel>> getWorkshops({String? token}) async {
    final list = await _client.getList('/api/v1/talleres', token: token);
    return list.map((json) => WorkshopModel.fromJson(json)).toList();
  }

  Future<List<AssistanceModel>> getAssistances({String? token}) async {
    final list = await _client.getList('/api/v1/asistencias', token: token);
    return list.map((json) => AssistanceModel.fromJson(json)).toList();
  }
}
