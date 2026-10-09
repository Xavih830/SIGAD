import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/models/extraction_schema_model.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/repositories/extraction_schemas_repository.dart';
import '../helpers/test_factories.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('ExtractionSchemasRepository Unit Tests', () {
    final mockSchema = TestFactories.createExtractionSchema();
    final mockSchemaJson = mockSchema.toJson();
    final mockListItem = TestFactories.createExtractionSchemaListItem();
    final mockListItemJson = mockListItem.toJson();

    test('getSchemas retorna lista de versiones de esquemas en HTTP 200', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.esquemas));
        expect(request.method, equals('GET'));
        expect(request.headers['Authorization'], equals('Bearer ${TestFixtures.validToken}'));
        return http.Response(
          jsonEncode([mockListItemJson]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ExtractionSchemasRepository(client: apiClient);

      final list = await repo.getSchemas(token: TestFixtures.validToken);

      expect(list, hasLength(1));
      expect(list.first.codigo, equals(mockListItem.codigo));
      expect(list.first.version, equals(mockListItem.version));
    });

    test('getSchemas propaga ApiForbiddenException ante HTTP 403', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          TestFixtures.errorDetailBody('Solo ADMIN y AGENTE pueden consultar esquemas.'),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ExtractionSchemasRepository(client: apiClient);

      expect(
        () => repo.getSchemas(token: TestFixtures.validToken),
        throwsA(isA<ApiForbiddenException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('getSchemaById retorna detalle completo del esquema en HTTP 200', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.esquema(mockSchema.id)));
        expect(request.method, equals('GET'));
        return http.Response(
          jsonEncode(mockSchemaJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ExtractionSchemasRepository(client: apiClient);

      final result = await repo.getSchemaById(mockSchema.id, token: TestFixtures.validToken);

      expect(result.id, equals(mockSchema.id));
      expect(result.codigo, equals(mockSchema.codigo));
      expect(result.campos, hasLength(mockSchema.campos.length));
    });

    test('getSchemaById propaga ApiException ante HTTP 404', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          TestFixtures.errorDetailBody('Esquema no encontrado.'),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ExtractionSchemasRepository(client: apiClient);

      expect(
        () => repo.getSchemaById('sch-inexistente', token: TestFixtures.validToken),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('createSchema envía payload de creación y retorna nueva versión', () async {
      final req = CreateSchemaRequest(
        codigo: 'NUEVO_ESQUEMA',
        nombre: 'Nuevo Esquema OCR',
        descripcion: 'Para pólizas generales',
        campos: [
          TestFactories.createExtractionField(nombre: 'prima', regex: r'\$(\d+\.\d{2})'),
        ],
      );

      final createdSchema = TestFactories.createExtractionSchema(
        codigo: req.codigo,
        nombre: req.nombre,
        version: 1,
        esActivo: false,
        campos: req.campos,
      );

      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.esquemas));
        expect(request.method, equals('POST'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['codigo'], equals('NUEVO_ESQUEMA'));
        return http.Response(
          jsonEncode(createdSchema.toJson()),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ExtractionSchemasRepository(client: apiClient);

      final result = await repo.createSchema(req, token: TestFixtures.validToken);

      expect(result.codigo, equals('NUEVO_ESQUEMA'));
      expect(result.version, equals(1));
      expect(result.esActivo, isFalse);
    });

    test('activateSchema envía PATCH sin cuerpo y retorna esquema activo', () async {
      final activeSchema = TestFactories.createExtractionSchema(
        id: mockSchema.id,
        esActivo: true,
      );

      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.esquemaActivar(mockSchema.id)));
        expect(request.method, equals('PATCH'));
        return http.Response(
          jsonEncode(activeSchema.toJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ExtractionSchemasRepository(client: apiClient);

      final result = await repo.activateSchema(mockSchema.id, token: TestFixtures.validToken);

      expect(result.esActivo, isTrue);
    });

    test('testSchema valida pre-flight y retorna TestSchemaResultModel en HTTP 200', () async {
      final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]);
      final testResult = TestFactories.createTestSchemaResult(
        confianza: 95.0,
        camposExtraidos: {'numero_poliza': 'POL-9999'},
      );

      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.esquemaProbar(mockSchema.id)));
        expect(request.method, equals('POST'));
        return http.Response(
          jsonEncode(testResult.toJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ExtractionSchemasRepository(client: apiClient);

      final result = await repo.testSchema(
        mockSchema.id,
        bytes: pdfBytes,
        filename: 'poliza_test.pdf',
        token: TestFixtures.validToken,
      );

      expect(result.confianza, equals(95.0));
      expect(result.camposExtraidos['numero_poliza'], equals('POL-9999'));
    });

    test('testSchema falla en pre-flight si los magic bytes son inválidos sin enviar petición HTTP', () async {
      final invalidBytes = Uint8List.fromList([0x00, 0x01, 0x02]);

      final mockHttpClient = MockClient((request) async {
        fail('No debe enviar petición HTTP si falla pre-flight');
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ExtractionSchemasRepository(client: apiClient);

      expect(
        () => repo.testSchema(
          mockSchema.id,
          bytes: invalidBytes,
          filename: 'archivo_falso.pdf',
          token: TestFixtures.validToken,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
