import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/models/policy_schema_model.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/repositories/policy_schemas_repository.dart';
import 'package:sigad/core/testing/test_factories.dart';
import 'package:sigad/core/testing/test_fixtures.dart';

void main() {
  group('PolicySchemasRepository Unit Tests', () {
    final mockSchema = TestFactories.createPolicySchema();
    final mockSchemaJson = mockSchema.toJson();
    final mockListItem = TestFactories.createPolicySchemaListItem();
    final mockListItemJson = mockListItem.toJson();

    test('getSchemas retorna lista de versiones de esquemas en HTTP 200', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.esquemasPoliza));
        expect(request.method, equals('GET'));
        expect(request.headers['Authorization'], equals('Bearer ${TestFixtures.validToken}'));
        return http.Response(
          jsonEncode([mockListItemJson]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PolicySchemasRepository(client: apiClient);

      final list = await repo.getSchemas(token: TestFixtures.validToken);

      expect(list, hasLength(1));
      expect(list.first.codigo, equals(mockListItem.codigo));
      expect(list.first.version, equals(mockListItem.version));
    });

    test('getSchemaById retorna detalle completo del esquema en HTTP 200', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.esquemaPoliza(mockSchema.id)));
        expect(request.method, equals('GET'));
        return http.Response(
          jsonEncode(mockSchemaJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PolicySchemasRepository(client: apiClient);

      final result = await repo.getSchemaById(mockSchema.id, token: TestFixtures.validToken);

      expect(result.id, equals(mockSchema.id));
      expect(result.codigo, equals(mockSchema.codigo));
      expect(result.campos, hasLength(mockSchema.campos.length));
    });

    test('createSchema envía payload de creación y retorna nueva versión', () async {
      final req = CreatePolicySchemaRequest(
        codigo: 'ESQ_NUEVO',
        nombre: 'Nuevo Esquema',
        descripcion: 'Detalle',
        campos: [
          TestFactories.createPolicySchemaField(nombre: 'rastreo_satelital', tipo: 'booleano', esObligatorio: true),
        ],
      );

      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.esquemasPoliza));
        expect(request.method, equals('POST'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['codigo'], equals('ESQ_NUEVO'));
        expect(body['nombre'], equals('Nuevo Esquema'));

        return http.Response(
          jsonEncode(mockSchemaJson),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PolicySchemasRepository(client: apiClient);

      final result = await repo.createSchema(req, token: TestFixtures.validToken);

      expect(result.id, equals(mockSchema.id));
      expect(result.codigo, equals(mockSchema.codigo));
    });

    test('activateSchema realiza PATCH al endpoint de activación', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.esquemaPolizaActivar(mockSchema.id)));
        expect(request.method, equals('PATCH'));
        return http.Response(
          jsonEncode(mockSchemaJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PolicySchemasRepository(client: apiClient);

      final result = await repo.activateSchema(mockSchema.id, token: TestFixtures.validToken);

      expect(result.id, equals(mockSchema.id));
    });
  });
}
