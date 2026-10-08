import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/repositories/documents_repository.dart';
import '../helpers/test_factories.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('DocumentsRepository Unit Tests (Zero Shotgun Surgery)', () {
    final mockDoc = TestFixtures.ocrDocumentModel;
    final mockDocJson = TestFixtures.ocrDocumentSample;

    test('getDocuments retorna lista de DocumentModel en HTTP 200', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.documentos));
        expect(request.method, equals('GET'));
        expect(request.headers['Authorization'], equals('Bearer ${TestFixtures.validToken}'));
        return http.Response(
          jsonEncode([mockDocJson]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = DocumentsRepository(client: apiClient);

      final result = await repo.getDocuments(token: TestFixtures.validToken);

      expect(result, hasLength(1));
      expect(result.first.id, equals(mockDoc.id));
      expect(result.first.nombreArchivo, equals(mockDoc.nombreArchivo));
    });

    test('getDocumentById retorna DocumentModel en HTTP 200', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.documento(mockDoc.id)));
        expect(request.method, equals('GET'));
        return http.Response(
          jsonEncode(mockDocJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = DocumentsRepository(client: apiClient);

      final result = await repo.getDocumentById(mockDoc.id, token: TestFixtures.validToken);

      expect(result.id, equals(mockDoc.id));
      expect(result.estadoExtraccion, equals(mockDoc.estadoExtraccion));
      expect(result.confianza, equals(mockDoc.confianza));
    });

    test('getDocumentById propaga ApiException ante HTTP 404', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          TestFixtures.errorDetailBody('Documento no encontrado.'),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = DocumentsRepository(client: apiClient);

      expect(
        () => repo.getDocumentById('doc-inexistente', token: TestFixtures.validToken),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('downloadDocumentBytes descarga bytes binarios en HTTP 200 con token de autorización', () async {
      final expectedBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]); // %PDF-1.4

      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.documentoDescarga(mockDoc.id)));
        expect(request.method, equals('GET'));
        expect(request.headers['Authorization'], equals('Bearer ${TestFixtures.validToken}'));
        return http.Response.bytes(
          expectedBytes,
          200,
          headers: {'content-type': 'application/pdf'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = DocumentsRepository(client: apiClient);

      final resultBytes = await repo.downloadDocumentBytes(mockDoc.id, token: TestFixtures.validToken);

      expect(resultBytes, equals(expectedBytes));
    });

    test('downloadDocumentBytes propaga ApiForbiddenException ante HTTP 403 (Anti-IDOR)', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          TestFixtures.errorDetailBody('Acceso denegado: el documento no pertenece a sus pólizas.'),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = DocumentsRepository(client: apiClient);

      expect(
        () => repo.downloadDocumentBytes(mockDoc.id, token: TestFixtures.validToken),
        throwsA(isA<ApiForbiddenException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('downloadDocumentBytes propaga ApiException ante HTTP 404 (archivo no existe)', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          TestFixtures.errorDetailBody('Archivo físico no encontrado.'),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = DocumentsRepository(client: apiClient);

      expect(
        () => repo.downloadDocumentBytes(mockDoc.id, token: TestFixtures.validToken),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('confirmRevision envía patch con campos corregidos y retorna DocumentModel actualizado', () async {
      final updatedDoc = TestFactories.createDocument(
        id: mockDoc.id,
        estadoExtraccion: 'completado',
        camposExtraidos: {'placa': 'PBX-1234', 'valor_asegurado': '19000.00'},
      );
      final updatedDocJson = TestFactories.createDocumentJson(
        id: updatedDoc.id,
        estadoExtraccion: 'completado',
        camposExtraidos: updatedDoc.camposExtraidos,
      );

      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.documentoRevision(mockDoc.id)));
        expect(request.method, equals('PATCH'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['estado_extraccion'], equals('completado'));
        expect(body['campos_extraidos']['valor_asegurado'], equals('19000.00'));
        return http.Response(
          jsonEncode(updatedDocJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = DocumentsRepository(client: apiClient);

      final result = await repo.confirmRevision(
        documentId: mockDoc.id,
        camposCorregidos: {'placa': 'PBX-1234', 'valor_asegurado': '19000.00'},
        token: TestFixtures.validToken,
      );

      expect(result.estadoExtraccion, equals('completado'));
    });
  });
}
