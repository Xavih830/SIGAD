import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/repositories/clients_repository.dart';
import '../helpers/test_factories.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('ClientsRepository Unit Tests', () {
    final mockClient = TestFixtures.standardClient;
    final mockClientJson = TestFixtures.standardClientJson;

    test('getClients retorna lista de ClientModel en HTTP 200', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.clientes));
        expect(request.method, equals('GET'));
        expect(request.headers['Authorization'], equals('Bearer ${TestFixtures.validToken}'));
        return http.Response(
          jsonEncode([mockClientJson]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ClientsRepository(client: apiClient);

      final result = await repo.getClients(token: TestFixtures.validToken);

      expect(result, hasLength(1));
      expect(result.first.id, equals(mockClient.id));
      expect(result.first.identificacion, equals(mockClient.identificacion));
      expect(result.first.nombres, equals(mockClient.nombres));
    });

    test('getClientById retorna ClientModel en HTTP 200 con deserialización canónica', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.cliente(mockClient.id)));
        expect(request.method, equals('GET'));
        expect(request.headers['Authorization'], equals('Bearer ${TestFixtures.validToken}'));
        return http.Response(
          jsonEncode(mockClientJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ClientsRepository(client: apiClient);

      final result = await repo.getClientById(mockClient.id, token: TestFixtures.validToken);

      expect(result.id, equals(mockClient.id));
      expect(result.identificacion, equals(mockClient.identificacion));
      expect(result.email, equals(mockClient.email));
    });

    test('getClientById propaga ApiException ante HTTP 404 (cliente inexistente)', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          TestFixtures.errorDetailBody('Cliente no encontrado.'),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ClientsRepository(client: apiClient);

      expect(
        () => repo.getClientById('cli-inexistente', token: TestFixtures.validToken),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('getClientById propaga ApiForbiddenException ante HTTP 403', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          TestFixtures.errorDetailBody('Acceso denegado a ficha de cliente ajena.'),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ClientsRepository(client: apiClient);

      expect(
        () => repo.getClientById(mockClient.id, token: TestFixtures.validToken),
        throwsA(isA<ApiForbiddenException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('createClient envía payload y retorna ClientModel creado en HTTP 201', () async {
      final newClient = TestFactories.createClient(id: 'cli-new-1');
      final newClientJson = newClient.toJson();

      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.clientes));
        expect(request.method, equals('POST'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['identificacion'], equals(newClient.identificacion));
        expect(body['nombres'], equals(newClient.nombres));
        return http.Response(
          jsonEncode(newClientJson),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ClientsRepository(client: apiClient);

      final req = CreateClientRequest(
        identificacion: newClient.identificacion,
        nombres: newClient.nombres,
        email: newClient.email,
        telefono: newClient.telefono,
      );

      final result = await repo.createClient(req, token: TestFixtures.validToken);

      expect(result.id, equals(newClient.id));
      expect(result.identificacion, equals(newClient.identificacion));
    });

    test('requestOtp envía POST al endpoint canónico y retorna ClientModel con OTP', () async {
      final otpClient = TestFactories.createClient(codigoVinculacion: TestFixtures.validOtp);
      final otpClientJson = otpClient.toJson();

      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.clienteOtp(otpClient.id)));
        expect(request.method, equals('POST'));
        return http.Response(
          jsonEncode(otpClientJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = ClientsRepository(client: apiClient);

      final result = await repo.requestOtp(otpClient.id, token: TestFixtures.validToken);

      expect(result.codigoVinculacion, equals(TestFixtures.validOtp));
    });
  });
}
