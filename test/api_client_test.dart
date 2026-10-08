import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sigad/core/network/api_client.dart';
import 'helpers/test_fixtures.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('ApiClient Unit Tests', () {
    late MockHttpClient mockHttp;
    late ApiClient client;

    setUp(() {
      mockHttp = MockHttpClient();
      client = ApiClient(
        client: mockHttp,
        baseUrl: TestFixtures.testBaseUrl,
        tokenProvider: () => TestFixtures.validToken,
      );
    });

    test('getList resuelve peticion GET y retorna lista de mapas', () async {
      when(() => mockHttp.get(
            Uri.parse('${TestFixtures.testBaseUrl}/api/v1/items'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode([
              {'id': '1', 'name': 'Item 1'},
              {'id': '2', 'name': 'Item 2'},
            ]),
            200,
          ));

      final result = await client.getList('/api/v1/items');

      expect(result.length, equals(2));
      expect(result.first['name'], equals('Item 1'));
    });

    test('getMap resuelve peticion GET y retorna mapa decodificado', () async {
      when(() => mockHttp.get(
            Uri.parse('${TestFixtures.testBaseUrl}/api/v1/items/1'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'id': '1', 'name': 'Item 1'}),
            200,
          ));

      final result = await client.getMap('/api/v1/items/1');

      expect(result['id'], equals('1'));
      expect(result['name'], equals('Item 1'));
    });

    test('post envia cuerpo JSON serializado y cabeceras de autorizacion', () async {
      when(() => mockHttp.post(
            Uri.parse('${TestFixtures.testBaseUrl}/api/v1/items'),
            headers: any(named: 'headers'),
            body: jsonEncode({'name': 'Nuevo'}),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'id': '3', 'name': 'Nuevo'}),
            201,
          ));

      final result = await client.post(
        '/api/v1/items',
        body: {'name': 'Nuevo'},
      );

      expect(result['id'], equals('3'));
      expect(result['name'], equals('Nuevo'));
    });

    test('patch envia actualizacion parcial y procesa respuesta', () async {
      when(() => mockHttp.patch(
            Uri.parse('${TestFixtures.testBaseUrl}/api/v1/items/3'),
            headers: any(named: 'headers'),
            body: jsonEncode({'name': 'Modificado'}),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'id': '3', 'name': 'Modificado'}),
            200,
          ));

      final result = await client.patch(
        '/api/v1/items/3',
        body: {'name': 'Modificado'},
      );

      expect(result['name'], equals('Modificado'));
    });

    test('Lanza ApiException con codigo de estado y mensaje cuando la API falla', () async {
      when(() => mockHttp.get(
            Uri.parse('${TestFixtures.testBaseUrl}/api/v1/error'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'detail': 'Recurso no encontrado'}),
            404,
          ));

      expect(
        () => client.getMap('/api/v1/error'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', equals(404))
              .having((e) => e.message, 'message', contains('Recurso no encontrado')),
        ),
      );
    });

    test('Token explicito tiene prioridad sobre tokenProvider', () async {
      Map<String, String>? capturedHeaders;

      when(() => mockHttp.get(
            Uri.parse('${TestFixtures.testBaseUrl}/api/v1/token-test'),
            headers: any(named: 'headers'),
          )).thenAnswer((invocation) async {
        capturedHeaders = invocation.namedArguments[#headers] as Map<String, String>?;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      await client.getMap('/api/v1/token-test', token: TestFixtures.manualOverrideToken);

      expect(capturedHeaders?['Authorization'], equals('Bearer ${TestFixtures.manualOverrideToken}'));
    });

    test('getBytes resuelve peticion GET y retorna Uint8List en HTTP 200', () async {
      final expectedBytes = [1, 2, 3, 4];
      when(() => mockHttp.get(
            Uri.parse('${TestFixtures.testBaseUrl}/api/v1/download'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response.bytes(
            expectedBytes,
            200,
          ));

      final result = await client.getBytes('/api/v1/download');

      expect(result, equals(expectedBytes));
    });
  });
}
