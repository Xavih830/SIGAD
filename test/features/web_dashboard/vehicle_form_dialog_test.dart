import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/vehicle_form_dialog.dart';

void main() {
  final testClient = ClientModel(
    id: 'cli-test-uuid-1234',
    identificacion: '0926687856',
    nombres: 'Juan Carlos Perez',
    email: 'juan.perez@test.sigad.ec',
    telefono: '0991234567',
  );

  group('VehicleFormDialog Widget Tests', () {
    testWidgets('Muestra encabezado de solo lectura con datos del cliente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleFormDialog(client: testClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cliente: Juan Carlos Perez'), findsOneWidget);
      expect(find.text('Identificación: 0926687856'), findsOneWidget);
      expect(find.text('Registrar Vehículo'), findsOneWidget);
    });

    testWidgets('Rechaza la placa PBA123 por formato inválido', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleFormDialog(client: testClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter invalid plate
      await tester.enterText(find.byType(TextFormField).at(0), 'PBA123');
      await tester.pumpAndSettle();

      // Tap guardar
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Formato inválido (ej. PBA-1234, AB-1234)'), findsOneWidget);
    });

    testWidgets('Acepta PBA-1234 y muestra chip Particular en vivo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleFormDialog(client: testClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'PBA-1234');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Chip, 'Particular'), findsOneWidget);
    });

    testWidgets('Rechaza un chasis de 16 caracteres', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleFormDialog(client: testClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Llenar campos
      await tester.enterText(find.byType(TextFormField).at(0), 'PBA-1234');
      await tester.enterText(find.byType(TextFormField).at(1), 'Toyota');
      await tester.enterText(find.byType(TextFormField).at(2), 'Corolla');
      await tester.enterText(find.byType(TextFormField).at(3), '2023');
      await tester.enterText(find.byType(TextFormField).at(4), 'Blanco');
      await tester.enterText(find.byType(TextFormField).at(5), 'MOT-123456');
      // 16 caracteres
      await tester.enterText(find.byType(TextFormField).at(6), '1HGCR2F83HA12345');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Debe tener exactamente 17 caracteres'), findsOneWidget);
    });

    testWidgets('Envía el request con el cliente_id correcto cuando los datos son válidos', (tester) async {
      CreateVehicleRequest? capturedRequest;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VehicleFormDialog(
              client: testClient,
              onSubmit: (req) async {
                capturedRequest = req;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'PBA-1234');
      await tester.enterText(find.byType(TextFormField).at(1), 'Toyota');
      await tester.enterText(find.byType(TextFormField).at(2), 'Corolla Cross');
      await tester.enterText(find.byType(TextFormField).at(3), '2024');
      await tester.enterText(find.byType(TextFormField).at(4), 'Plata');
      await tester.enterText(find.byType(TextFormField).at(5), '2ZR-FE987654');
      await tester.enterText(find.byType(TextFormField).at(6), '1HGCR2F83HA123456');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.clientId, equals('cli-test-uuid-1234'));
      expect(capturedRequest!.plate, equals('PBA-1234'));
      expect(capturedRequest!.brand, equals('Toyota'));
      expect(capturedRequest!.model, equals('Corolla Cross'));
      expect(capturedRequest!.year, equals(2024));
      expect(capturedRequest!.color, equals('PLATA'));
      expect(capturedRequest!.motor, equals('2ZR-FE987654'));
      expect(capturedRequest!.chasis, equals('1HGCR2F83HA123456'));
    });
  });
}
