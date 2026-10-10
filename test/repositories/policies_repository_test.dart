import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/repositories/policies_repository.dart';
import 'package:sigad/core/testing/test_factories.dart';
import 'package:sigad/core/testing/test_fixtures.dart';

void main() {
  group('PoliciesRepository Unit Tests', () {
    final mockPolicy = TestFixtures.activePolicy;
    final mockPolicyJson = TestFixtures.activePolicyJson;
    final mockVehicle = TestFixtures.standardVehicle;
    final mockVehicleJson = TestFixtures.standardVehicleJson;
    final mockDeductible = TestFixtures.standardDeductible;
    final mockDeductibleJson = TestFixtures.standardDeductibleJson;

    test('getPolicies retorna listado tipado en HTTP 200 con paginación', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.polizasBase));
        expect(request.url.queryParameters['skip'], equals('0'));
        expect(request.url.queryParameters['limit'], equals('50'));
        expect(request.headers['Authorization'], equals('Bearer ${TestFixtures.validToken}'));
        return http.Response(
          jsonEncode([mockPolicyJson]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PoliciesRepository(client: apiClient);

      final result = await repo.getPolicies(token: TestFixtures.validToken);

      expect(result, hasLength(1));
      expect(result.first.id, equals(mockPolicy.id));
      expect(result.first.number, equals(mockPolicy.number));
    });

    test('getPolicy retorna PolicyModel por ID en HTTP 200', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.poliza(mockPolicy.id)));
        expect(request.method, equals('GET'));
        return http.Response(
          jsonEncode(mockPolicyJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PoliciesRepository(client: apiClient);

      final result = await repo.getPolicy(mockPolicy.id, token: TestFixtures.validToken);

      expect(result.id, equals(mockPolicy.id));
      expect(result.number, equals(mockPolicy.number));
      expect(result.insuredValue, equals(mockPolicy.insuredValue));
    });

    test('getPolicy propaga ApiException ante HTTP 404', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          TestFixtures.errorDetailBody('Póliza no encontrada.'),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PoliciesRepository(client: apiClient);

      expect(
        () => repo.getPolicy('pol-inexistente', token: TestFixtures.validToken),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('getPolicy propaga ApiForbiddenException ante HTTP 403', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          TestFixtures.errorDetailBody('Acceso no autorizado a póliza ajena.'),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PoliciesRepository(client: apiClient);

      expect(
        () => repo.getPolicy(mockPolicy.id, token: TestFixtures.validToken),
        throwsA(isA<ApiForbiddenException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('getPolicyDeductibles retorna lista de DeductibleModel consumiendo endpoint canónico', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.polizaDeducibles(mockPolicy.id)));
        expect(request.method, equals('GET'));
        expect(request.headers['Authorization'], equals('Bearer ${TestFixtures.validToken}'));
        return http.Response(
          jsonEncode([mockDeductibleJson]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PoliciesRepository(client: apiClient);

      final result = await repo.getPolicyDeductibles(mockPolicy.id, token: TestFixtures.validToken);

      expect(result, hasLength(1));
      expect(result.first.tipoSiniestro, equals(mockDeductible.tipoSiniestro));
      expect(result.first.porcentajeValor, equals(mockDeductible.porcentajeValor));
      expect(result.first.montoMinimoUsd, equals(mockDeductible.montoMinimoUsd));
    });

    test('getVehicleById retorna VehicleModel consumiendo ApiEndpoints.vehiculo(vehicleId)', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.vehiculo(mockVehicle.id!)));
        expect(request.method, equals('GET'));
        expect(request.headers['Authorization'], equals('Bearer ${TestFixtures.validToken}'));
        return http.Response(
          jsonEncode(mockVehicleJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PoliciesRepository(client: apiClient);

      final result = await repo.getVehicleById(mockVehicle.id!, token: TestFixtures.validToken);

      expect(result.id, equals(mockVehicle.id));
      expect(result.plate, equals(mockVehicle.plate));
      expect(result.brand, equals(mockVehicle.brand));
      expect(result.model, equals(mockVehicle.model));
      expect(result.year, equals(mockVehicle.year));
    });

    test('getVehicleById propaga ApiException ante HTTP 404', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          TestFixtures.errorDetailBody('Vehículo no encontrado.'),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PoliciesRepository(client: apiClient);

      expect(
        () => repo.getVehicleById('veh-inexistente', token: TestFixtures.validToken),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('updatePolicyStatus envía PATCH y retorna PolicyModel actualizado', () async {
      final updatedPolicy = TestFactories.createPolicy(id: mockPolicy.id, status: 'cancelada');
      final updatedPolicyJson = updatedPolicy.toJson();

      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals(ApiEndpoints.polizaEstado(mockPolicy.id)));
        expect(request.method, equals('PATCH'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['estado'], equals('cancelada'));
        return http.Response(
          jsonEncode(updatedPolicyJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PoliciesRepository(client: apiClient);

      final result = await repo.updatePolicyStatus(mockPolicy.id, 'cancelada', token: TestFixtures.validToken);

      expect(result.status, equals('cancelada'));
    });

    test('createPolicy envía POST con CreatePolicyRequest y retorna PolicyModel', () async {
      final request = TestFactories.createPolicyRequest(vehicleId: mockVehicle.id);

      final mockHttpClient = MockClient((httpRequest) async {
        expect(httpRequest.url.path, equals(ApiEndpoints.polizasBase));
        expect(httpRequest.method, equals('POST'));
        expect(httpRequest.headers['Authorization'], equals('Bearer ${TestFixtures.validToken}'));

        final body = jsonDecode(httpRequest.body) as Map<String, dynamic>;
        expect(body['numero_poliza'], equals(request.number));
        expect(body['vehiculo_id'], equals(mockVehicle.id));

        return http.Response(
          jsonEncode(mockPolicyJson),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PoliciesRepository(client: apiClient);

      final result = await repo.createPolicy(request, token: TestFixtures.validToken);

      expect(result.id, equals(mockPolicy.id));
      expect(result.number, equals(mockPolicy.number));
    });

    test('createPolicy lanza StateError si falta vehículo y no puede resolverse', () async {
      final request = TestFactories.createPolicyRequest(vehicleId: null, vehicle: null);

      final mockHttpClient = MockClient((httpRequest) async {
        return http.Response('{}', 200);
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      final repo = PoliciesRepository(client: apiClient);

      expect(
        () => repo.createPolicy(request, token: TestFixtures.validToken),
        throwsA(isA<StateError>()),
      );
    });
  });
}
