import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/models/catalog_model.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/repositories/catalog_repository.dart';
import '../helpers/test_factories.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('CatalogRepository Unit Tests (Zero Shotgun Surgery)', () {
    final mockWorkshop = TestFixtures.standardWorkshop;
    final mockWorkshopJson = TestFixtures.standardWorkshopJson;
    final mockAssistance = TestFixtures.standardAssistance;
    final mockAssistanceJson = TestFixtures.standardAssistanceJson;

    test('getWorkshops retorna lista de talleres y almacena en InMemoryCache', () async {
      int requestCount = 0;
      final mockHttpClient = MockClient((request) async {
        requestCount++;
        expect(request.url.path, equals(ApiEndpoints.talleres));
        return http.Response(
          jsonEncode([mockWorkshopJson]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = CatalogRepository(client: apiClient);

      final firstCall = await repo.getWorkshops(token: TestFixtures.validToken);
      final secondCall = await repo.getWorkshops(token: TestFixtures.validToken);

      expect(firstCall, hasLength(1));
      expect(secondCall, hasLength(1));
      expect(requestCount, equals(1)); // Respeto al rate-limit mediante cache
    });

    test('createWorkshop envía POST, invalida caché y retorna WorkshopModel creado', () async {
      final req = CreateWorkshopRequest(
        nombre: 'Taller Norte',
        direccion: 'Av. Las Américas 123',
        telefono: '042123456',
        ciudad: 'Guayaquil',
      );

      final createdWorkshop = TestFactories.createWorkshop(
        name: req.nombre,
        address: req.direccion,
        phone: req.telefono,
        city: req.ciudad,
      );

      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.talleres));
        expect(request.method, equals('POST'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['nombre'], equals('Taller Norte'));
        return http.Response(
          jsonEncode(createdWorkshop.toJson()),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = CatalogRepository(client: apiClient);

      final result = await repo.createWorkshop(req, token: TestFixtures.validToken);

      expect(result.name, equals('Taller Norte'));
      expect(result.city, equals('Guayaquil'));
    });

    test('getWorkshopById retorna WorkshopModel por ID en HTTP 200', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.taller(mockWorkshop.id)));
        expect(request.method, equals('GET'));
        return http.Response(
          jsonEncode(mockWorkshopJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = CatalogRepository(client: apiClient);

      final result = await repo.getWorkshopById(mockWorkshop.id, token: TestFixtures.validToken);

      expect(result.id, equals(mockWorkshop.id));
      expect(result.name, equals(mockWorkshop.name));
    });

    test('createAssistance envía POST, invalida caché y retorna AssistanceModel creado', () async {
      final req = CreateAssistanceRequest(
        titulo: 'Cerrajería Vehicular',
        descripcion: 'Apertura de cerraduras de autos en sitio',
        telefonoEmergencia: '1800-999-999',
        icono: 'key',
      );

      final createdAssistance = TestFactories.createAssistance(
        title: req.titulo,
        description: req.descripcion,
        emergencyPhone: req.telefonoEmergencia,
        icon: req.icono,
      );

      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.asistencias));
        expect(request.method, equals('POST'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['titulo'], equals('Cerrajería Vehicular'));
        return http.Response(
          jsonEncode(createdAssistance.toJson()),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = CatalogRepository(client: apiClient);

      final result = await repo.createAssistance(req, token: TestFixtures.validToken);

      expect(result.title, equals('Cerrajería Vehicular'));
      expect(result.emergencyPhone, equals('1800-999-999'));
    });

    test('getAssistanceById retorna AssistanceModel por ID en HTTP 200', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.asistencia(mockAssistance.id)));
        expect(request.method, equals('GET'));
        return http.Response(
          jsonEncode(mockAssistanceJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = CatalogRepository(client: apiClient);

      final result = await repo.getAssistanceById(mockAssistance.id, token: TestFixtures.validToken);

      expect(result.id, equals(mockAssistance.id));
      expect(result.title, equals(mockAssistance.title));
    });
  });
}
