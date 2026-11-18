import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/network/session_events.dart';
import 'package:sigad/core/services/session_vault.dart';
import 'package:sigad/core/testing/test_fixtures.dart';

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

    test('getList lanza ApiException si el backend devuelve un objeto en vez de lista', () async {
      when(() => mockHttp.get(
            Uri.parse('${TestFixtures.testBaseUrl}/api/v1/invalid-list'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'mensaje': 'no es una lista'}),
            200,
          ));

      expect(() => client.getList('/api/v1/invalid-list'), throwsA(isA<ApiException>()));
    });

    test('multipart lanza ArgumentError si la extension de archivo no es permitida', () async {
      expect(
        () => client.multipart(
          path: '/api/v1/documentos',
          bytes: Uint8List.fromList([1, 2, 3]),
          filename: 'malware.exe',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('401 -> refresh OK -> reintento OK -> devuelve los datos', () async {
      SessionVault.enableTestMode(initialSession: {
        'access_token': 'expired_access',
        'refresh_token': 'valid_refresh',
      });

      final customClient = ApiClient(
        client: mockHttp,
        baseUrl: TestFixtures.testBaseUrl,
      );

      var getCalls = 0;
      when(() => mockHttp.get(
            Uri.parse('${TestFixtures.testBaseUrl}/api/v1/items/protected'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async {
        getCalls++;
        if (getCalls == 1) {
          return http.Response(jsonEncode({'detail': 'Token expired'}), 401);
        }
        return http.Response(jsonEncode({'status': 'success'}), 200);
      });

      when(() => mockHttp.post(
            Uri.parse('${TestFixtures.testBaseUrl}${ApiEndpoints.authRefresh}'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'access_token': 'new_access_token',
              'refresh_token': 'new_refresh_token',
            }),
            200,
          ));

      final result = await customClient.getMap('/api/v1/items/protected');

      expect(result['status'], equals('success'));
      expect(getCalls, equals(2));
      expect(SessionVault.currentAccessToken, equals('new_access_token'));
      SessionVault.resetTestMode();
    });

    test('401 -> refresh 401 -> se emite SessionEvents.onExpired y se lanza ApiException', () async {
      SessionVault.enableTestMode(initialSession: {
        'access_token': 'expired_access',
        'refresh_token': 'revoked_refresh',
      });

      final customClient = ApiClient(
        client: mockHttp,
        baseUrl: TestFixtures.testBaseUrl,
      );

      when(() => mockHttp.get(
            Uri.parse('${TestFixtures.testBaseUrl}/api/v1/items/protected'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'detail': 'Token expired'}),
            401,
          ));

      when(() => mockHttp.post(
            Uri.parse('${TestFixtures.testBaseUrl}${ApiEndpoints.authRefresh}'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'detail': 'Sesión inválida o expirada.'}),
            401,
          ));

      bool expiredEmitted = false;
      final sub = SessionEvents.onExpired.listen((_) {
        expiredEmitted = true;
      });

      expect(
        () => customClient.getMap('/api/v1/items/protected'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(expiredEmitted, isTrue);
      await sub.cancel();
      SessionVault.resetTestMode();
    });

    test('Dos peticiones concurrentes con 401 -> el endpoint de refresh se llama una sola vez', () async {
      SessionVault.enableTestMode(initialSession: {
        'access_token': 'expired_access',
        'refresh_token': 'valid_refresh',
      });

      final customClient = ApiClient(
        client: mockHttp,
        baseUrl: TestFixtures.testBaseUrl,
      );

      var refreshCalls = 0;
      when(() => mockHttp.post(
            Uri.parse('${TestFixtures.testBaseUrl}${ApiEndpoints.authRefresh}'),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {
        refreshCalls++;
        await Future.delayed(const Duration(milliseconds: 30));
        return http.Response(
          jsonEncode({
            'access_token': 'refreshed_access',
            'refresh_token': 'refreshed_refresh',
          }),
          200,
        );
      });

      var call1Count = 0;
      when(() => mockHttp.get(
            Uri.parse('${TestFixtures.testBaseUrl}/api/v1/items/1'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async {
        call1Count++;
        if (call1Count == 1) {
          return http.Response(jsonEncode({'detail': 'Token expired'}), 401);
        }
        return http.Response(jsonEncode({'id': '1'}), 200);
      });

      var call2Count = 0;
      when(() => mockHttp.get(
            Uri.parse('${TestFixtures.testBaseUrl}/api/v1/items/2'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async {
        call2Count++;
        if (call2Count == 1) {
          return http.Response(jsonEncode({'detail': 'Token expired'}), 401);
        }
        return http.Response(jsonEncode({'id': '2'}), 200);
      });

      final results = await Future.wait([
        customClient.getMap('/api/v1/items/1'),
        customClient.getMap('/api/v1/items/2'),
      ]);

      expect(results[0]['id'], equals('1'));
      expect(results[1]['id'], equals('2'));
      expect(refreshCalls, equals(1));
      SessionVault.resetTestMode();
    });
  });
}
