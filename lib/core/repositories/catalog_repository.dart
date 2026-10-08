import 'package:http/http.dart' as http;
import 'package:sigad/core/cache/in_memory_cache.dart';
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/constants/app_constants.dart';
import 'package:sigad/core/models/catalog_model.dart';
import 'package:sigad/core/network/api_client.dart';

/// Repositorio canónico para consulta de catálogos (talleres y asistencias viales).
///
/// Utiliza [InMemoryCache] desacoplado para respetar el rate limit del backend (60 req/min)
/// sin entrelazar lógica de expiración con la lógica de red.
class CatalogRepository {
  final ApiClient _client;
  final InMemoryCache<List<WorkshopModel>> _workshopsCache;
  final InMemoryCache<List<AssistanceModel>> _assistancesCache;

  CatalogRepository({
    ApiClient? client,
    http.Client? httpClient,
    Duration cacheTtl = AppConstants.catalogCacheTtl,
  })  : _client = client ?? ApiClient(client: httpClient),
        _workshopsCache = InMemoryCache(ttl: cacheTtl),
        _assistancesCache = InMemoryCache(ttl: cacheTtl);

  Future<List<WorkshopModel>> getWorkshops({String? token, bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _workshopsCache.get();
      if (cached != null) return cached;
    }
    final list = await _client.getList(ApiEndpoints.talleres, token: token);
    final workshops = list.map((json) => WorkshopModel.fromJson(json)).toList();
    _workshopsCache.set(workshops);
    return workshops;
  }

  Future<List<AssistanceModel>> getAssistances({String? token, bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _assistancesCache.get();
      if (cached != null) return cached;
    }
    final list = await _client.getList(ApiEndpoints.asistencias, token: token);
    final assistances = list.map((json) => AssistanceModel.fromJson(json)).toList();
    _assistancesCache.set(assistances);
    return assistances;
  }

  Future<WorkshopModel> createWorkshop(CreateWorkshopRequest request, {String? token}) async {
    final json = await _client.post(
      ApiEndpoints.talleres,
      body: request.toJson(),
      token: token,
    );
    _workshopsCache.invalidate();
    return WorkshopModel.fromJson(json);
  }

  Future<WorkshopModel> getWorkshopById(String id, {String? token}) async {
    final json = await _client.getMap(ApiEndpoints.taller(id), token: token);
    return WorkshopModel.fromJson(json);
  }

  Future<AssistanceModel> createAssistance(CreateAssistanceRequest request, {String? token}) async {
    final json = await _client.post(
      ApiEndpoints.asistencias,
      body: request.toJson(),
      token: token,
    );
    _assistancesCache.invalidate();
    return AssistanceModel.fromJson(json);
  }

  Future<AssistanceModel> getAssistanceById(String id, {String? token}) async {
    final json = await _client.getMap(ApiEndpoints.asistencia(id), token: token);
    return AssistanceModel.fromJson(json);
  }
}
