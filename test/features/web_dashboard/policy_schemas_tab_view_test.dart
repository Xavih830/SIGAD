import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sigad/core/models/policy_schema_model.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/repositories/policy_schemas_repository.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_schema_create_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/policy_schemas_tab_view.dart';
import 'package:sigad/core/testing/test_factories.dart';

void main() {
  group('PolicySchemasTabView & PolicySchemaCreateDialog Tests', () {
    testWidgets('PolicySchemasTabView muestra lista y carga campos al seleccionar esquema', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockList = [
        TestFactories.createPolicySchemaListItem(
          id: 'psch-1',
          codigo: 'VEHICULOS_PESADOS',
          nombre: 'Póliza Transporte Pesado',
          version: 1,
          esActivo: true,
        ),
      ];

      final mockDetail = TestFactories.createPolicySchema(
        id: 'psch-1',
        codigo: 'VEHICULOS_PESADOS',
        nombre: 'Póliza Transporte Pesado',
        descripcion: 'Esquema para camiones y carga pesada',
        version: 1,
        esActivo: true,
        campos: [
          TestFactories.createPolicySchemaField(
            nombre: 'tonelaje_maximo',
            tipo: 'decimal',
            esObligatorio: true,
            orden: 0,
          ),
          TestFactories.createPolicySchemaField(
            nombre: 'dispositivo_gps',
            tipo: 'booleano',
            esObligatorio: true,
            orden: 1,
          ),
        ],
      );

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/v1/esquemas-poliza') {
          return http.Response(jsonEncode(mockList.map((m) => m.toJson()).toList()), 200, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'GET' && request.url.path == '/api/v1/esquemas-poliza/psch-1') {
          return http.Response(jsonEncode(mockDetail.toJson()), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{"detail":"Not Found"}', 404);
      });

      final repo = PolicySchemasRepository(client: ApiClient(client: mockClient));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PolicySchemasTabView(
              repository: repo,
              authToken: 'test-token',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Gestión de Esquemas de Pólizas Vehiculares'), findsOneWidget);
      expect(find.text('Póliza Transporte Pesado'), findsWidgets);
      expect(find.text('tonelaje_maximo'), findsOneWidget);
      expect(find.text('dispositivo_gps'), findsOneWidget);
      expect(find.text('DECIMAL'), findsOneWidget);
      expect(find.text('BOOLEANO'), findsOneWidget);
    });

    testWidgets('PolicySchemaCreateDialog permite seleccionar plantilla rápida y configurar campos', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/esquemas-poliza') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final created = TestFactories.createPolicySchema(
            id: 'psch-new',
            codigo: body['codigo'] as String,
            nombre: body['nombre'] as String,
            version: 1,
            esActivo: false,
          );
          return http.Response(jsonEncode(created.toJson()), 201, headers: {'content-type': 'application/json'});
        }
        return http.Response('{"detail":"Error"}', 400);
      });

      final repo = PolicySchemasRepository(client: ApiClient(client: mockClient));

      PolicySchemaModel? createdResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  createdResult = await showDialog<PolicySchemaModel>(
                    context: ctx,
                    builder: (_) => PolicySchemaCreateDialog(
                      repository: repo,
                      authToken: 'test-token',
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo Esquema de Póliza Vehicular'), findsOneWidget);
      expect(find.text('Pesados / Carga'), findsOneWidget);
      expect(find.text('Livianos / Sedán'), findsOneWidget);
      expect(find.text('Motos'), findsOneWidget);

      // Cambiar a plantilla de Motos
      await tester.tap(find.text('Motos'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'MOTOCICLETAS'), findsOneWidget);

      // Guardar el esquema
      await tester.tap(find.text('Crear Esquema de Póliza'));
      await tester.pumpAndSettle();

      expect(createdResult, isNotNull);
      expect(createdResult!.codigo, equals('MOTOCICLETAS'));
    });
  });
}

