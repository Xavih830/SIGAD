import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/repositories/policy_schemas_repository.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_form_dialog.dart';
import 'package:sigad/core/testing/test_factories.dart';
import 'package:sigad/core/testing/test_fixtures.dart';

void main() {
  group('PolicyFormDialog with Dynamic Schema Tests', () {
    final client = TestFactories.createClient(id: 'cli-1', identificacion: '0926687856', nombres: 'Carlos Mendoza');
    final mockSchema = TestFactories.createPolicySchema(
      id: 'sch-pol-1',
      codigo: 'VEHICULAR_ESTANDAR',
      nombre: 'Póliza Estándar',
      version: 1,
      esActivo: true,
      campos: [
        TestFactories.createPolicySchemaField(
          nombre: 'rastreo_satelital',
          tipo: 'booleano',
          esObligatorio: false,
          orden: 1,
        ),
      ],
    );
    final mockSchemaListItem = TestFactories.createPolicySchemaListItem(
      id: 'sch-pol-1',
      codigo: 'VEHICULAR_ESTANDAR',
      nombre: 'Póliza Estándar',
      version: 1,
      esActivo: true,
    );

    late PolicySchemasRepository repo;

    setUp(() {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path == ApiEndpoints.esquemasPoliza) {
          return http.Response(
            jsonEncode([mockSchemaListItem.toJson()]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == ApiEndpoints.esquemaPoliza('sch-pol-1')) {
          return http.Response(
            jsonEncode(mockSchema.toJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl);
      repo = PolicySchemasRepository(client: apiClient);
    });

    testWidgets('Carga esquemas de póliza disponibles y renderiza formulario dinámico', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      CreatePolicyRequest? submittedRequest;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  submittedRequest = await showDialog<CreatePolicyRequest>(
                    context: ctx,
                    builder: (_) => PolicyFormDialog(
                      clients: [client],
                      policySchemasRepository: repo,
                      authToken: TestFixtures.validToken,
                    ),
                  );
                },
                child: const Text('Abrir Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Nueva Póliza Vehicular'), findsOneWidget);
      expect(find.text('Esquema de Campos de Póliza:'), findsOneWidget);

      // Esperar a que cargue el esquema activo por defecto
      expect(find.textContaining('Póliza Estándar (v1)'), findsWidgets);
      expect(find.textContaining('Rastreo Satelital'), findsOneWidget);

      // Llenar campos base requeridos
      await tester.enterText(find.widgetWithText(TextFormField, 'Número de Póliza'), 'POL-2026-TEST-001');
      await tester.enterText(find.widgetWithText(TextFormField, 'Marca'), 'Toyota');
      await tester.enterText(find.widgetWithText(TextFormField, 'Modelo'), 'Corolla');
      await tester.enterText(find.widgetWithText(TextFormField, 'Año'), '2023');
      await tester.enterText(find.widgetWithText(TextFormField, 'Placa Vehicular (Formato ANT, ej. PBA-1234)'), 'PBA-1234');
      await tester.enterText(find.widgetWithText(TextFormField, 'Valor Asegurado (USD)'), '20000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Prima Mensual (USD)'), '85');
      await tester.enterText(find.widgetWithText(TextFormField, 'Kilometraje de Emisión (Snapshot inmutable)'), '12000');
      await tester.pump();

      // Guardar formulario
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(submittedRequest, isNotNull);
      expect(submittedRequest!.number, equals('POL-2026-TEST-001'));
      expect(submittedRequest!.vehicle?.plate, equals('PBA-1234'));
      expect(submittedRequest!.insuredValue, equals(20000));
      expect(submittedRequest!.esquemaId, equals('sch-pol-1'));
      expect(submittedRequest!.camposAdicionales, isNotNull);
      expect(submittedRequest!.camposAdicionales!['rastreo_satelital'], equals(false));
    });
  });
}
