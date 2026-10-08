import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/repositories/extraction_schemas_repository.dart';
import 'package:sigad/core/security/app_capability.dart';
import 'package:sigad/core/security/authorization_policy.dart';
import 'package:sigad/features/web_dashboard/domain/dashboard_tab_registry.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/ocr_schemas_tab_view.dart';
import '../../helpers/test_factories.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  group('CBAC & OcrSchemasTabView Widget Tests (Anti-Vibecoding Gate)', () {
    test('Control de acceso CBAC: Solo rol ADMIN posee AppCapability.manageOcrSchemas y manageCatalogs', () {
      final admin = TestFixtures.adminUser;
      final agent = TestFactories.createUser(role: UserRole.agente);
      final client = TestFixtures.clientUser;

      expect(AuthorizationPolicy.canUser(admin, AppCapability.manageOcrSchemas), isTrue);
      expect(AuthorizationPolicy.canUser(admin, AppCapability.manageCatalogs), isTrue);

      expect(AuthorizationPolicy.canUser(agent, AppCapability.manageOcrSchemas), isFalse);
      expect(AuthorizationPolicy.canUser(agent, AppCapability.manageCatalogs), isFalse);

      expect(AuthorizationPolicy.canUser(client, AppCapability.manageOcrSchemas), isFalse);
      expect(AuthorizationPolicy.canUser(client, AppCapability.manageCatalogs), isFalse);
    });

    test('DashboardTabRegistry filtra pestaña schemas para agentes y clientes', () {
      final admin = TestFixtures.adminUser;
      final agent = TestFactories.createUser(role: UserRole.agente);
      final client = TestFixtures.clientUser;

      final adminTabs = DashboardTabRegistry.getPermittedTabs(admin);
      final agentTabs = DashboardTabRegistry.getPermittedTabs(agent);
      final clientTabs = DashboardTabRegistry.getPermittedTabs(client);

      expect(adminTabs.any((t) => t.id == 'schemas'), isTrue);
      expect(agentTabs.any((t) => t.id == 'schemas'), isFalse);
      expect(clientTabs.any((t) => t.id == 'schemas'), isFalse);
    });

    testWidgets('OcrSchemasTabView lista esquemas y muestra tabla de campos al seleccionar', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockItem = TestFactories.createExtractionSchemaListItem(
        id: 'sch-1',
        codigo: 'POLIZA_VEHICULO',
        nombre: 'Póliza Automotriz 2026',
        version: 1,
        esActivo: true,
      );

      final mockDetail = TestFactories.createExtractionSchema(
        id: 'sch-1',
        codigo: 'POLIZA_VEHICULO',
        nombre: 'Póliza Automotriz 2026',
        version: 1,
        esActivo: true,
        campos: [
          TestFactories.createExtractionField(nombre: 'numero_poliza', regex: r'POL-(\d+)'),
          TestFactories.createExtractionField(nombre: 'prima_mensual', regex: r'\$(\d+\.\d{2})'),
        ],
      );

      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/api/v1/esquemas') {
          return http.Response(jsonEncode([mockItem.toJson()]), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/v1/esquemas/sch-1') {
          return http.Response(jsonEncode(mockDetail.toJson()), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 200);
      });

      final repo = ExtractionSchemasRepository(
        client: ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrSchemasTabView(repository: repo),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Póliza Automotriz 2026'), findsWidgets);
      expect(find.text('POLIZA_VEHICULO • v1'), findsOneWidget);
      expect(find.text('ACTIVO'), findsOneWidget);
      expect(find.text('Probar con Documento'), findsOneWidget);
      expect(find.text('Versión Activa'), findsOneWidget);
    });
  });
}
