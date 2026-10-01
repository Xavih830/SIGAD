import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sigad/core/models/payment_model.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/features/mobile_client/presentation/pages/policy_detail_page.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  final testPolicy = PolicyModel(
    id: 'pol-100',
    number: 'POL-EC-2026-999',
    clientId: 'cli-100',
    vehicleId: 'veh-100',
    vehicle: const VehicleModel(
      id: 'veh-100',
      brand: 'Chevrolet',
      model: 'D-Max',
      year: 2024,
      plate: 'PBC-4321',
    ),
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2027, 1, 1),
    status: 'activa',
    insuredValue: 28000.0,
    monthlyPremium: 85.0,
    emissionMileage: 12000,
    coverages: const [
      CoverageModel(id: 'cov-1', nombre: 'Pérdida Total', monto: 10000),
      CoverageModel(id: 'cov-2', nombre: 'Responsabilidad Civil', monto: 5000),
    ],

  );

  group('HU-20: PaymentModel Unit Tests', () {
    test('PaymentModel.fromJson deserializa correctamente todos los campos', () {
      final json = {
        'id': 'pago-01',
        'poliza_id': 'pol-100',
        'numero_cuota': 1,
        'monto_usd': 85.0,
        'fecha_vencimiento': '2026-01-15',
        'fecha_pago': '2026-01-14',
        'estado': 'pagado',
        'metodo_pago': 'transferencia',
        'comprobante_ref': 'REF-TRX-12345',
      };

      final payment = PaymentModel.fromJson(json);

      expect(payment.id, equals('pago-01'));
      expect(payment.policyId, equals('pol-100'));
      expect(payment.installmentNumber, equals(1));
      expect(payment.amountUsd, equals(85.0));
      expect(payment.dueDate, equals(DateTime(2026, 1, 15)));
      expect(payment.paymentDate, equals(DateTime(2026, 1, 14)));
      expect(payment.status, equals('pagado'));
      expect(payment.paymentMethod, equals('transferencia'));
      expect(payment.receiptRef, equals('REF-TRX-12345'));
      expect(payment.isPaid, isTrue);
      expect(payment.isPending, isFalse);
      expect(payment.isOverdue, isFalse);
    });

    test('PaymentModel maneja campos nulos y calcula getters de estado', () {
      final json = {
        'id': 'pago-02',
        'poliza_id': 'pol-100',
        'numero_cuota': 2,
        'monto_usd': 85,
        'fecha_vencimiento': '2026-02-15',
        'fecha_pago': null,
        'estado': 'atrasado',
        'metodo_pago': null,
        'comprobante_ref': null,
      };

      final payment = PaymentModel.fromJson(json);

      expect(payment.paymentDate, isNull);
      expect(payment.paymentMethod, isNull);
      expect(payment.receiptRef, isNull);
      expect(payment.isPaid, isFalse);
      expect(payment.isPending, isFalse);
      expect(payment.isOverdue, isTrue);

      final exported = payment.toJson();
      expect(exported['numero_cuota'], equals(2));
      expect(exported['estado'], equals('atrasado'));
      expect(exported.containsKey('fecha_pago'), isFalse);
    });
  });

  group('HU-20: PolicyDetailPage Widget Tests', () {
    testWidgets('Renderiza desglose real de cuotas y estado financiero Al día', (tester) async {
      final payments = [
        PaymentModel(
          id: 'p1',
          policyId: 'pol-100',
          installmentNumber: 1,
          amountUsd: 85.0,
          dueDate: DateTime(2026, 1, 15),
          paymentDate: DateTime(2026, 1, 12),
          status: 'pagado',
          paymentMethod: 'transferencia',
          receiptRef: 'DEP-8899',
        ),
        PaymentModel(
          id: 'p2',
          policyId: 'pol-100',
          installmentNumber: 2,
          amountUsd: 85.0,
          dueDate: DateTime(2026, 2, 15),
          status: 'pendiente',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: PolicyDetailPage(
            policy: testPolicy,
            onReportError: () {},
            initialPayments: payments,
          ),
        ),
      );

      // Verify header details
      expect(find.text('POL-EC-2026-999'), findsOneWidget);
      expect(find.text('Cronograma de Pagos y Cuotas'), findsOneWidget);

      // Verify financial dynamic status
      expect(find.text('Al día'), findsOneWidget);

      // Verify installment cards
      expect(find.text('Cuota 1'), findsOneWidget);
      expect(find.text('PAGADO'), findsOneWidget);
      expect(find.textContaining('DEP-8899'), findsOneWidget);

      expect(find.text('Cuota 2'), findsOneWidget);
      expect(find.text('PENDIENTE'), findsOneWidget);
      expect(find.text('\$85.00 USD'), findsNWidgets(3));
    });

    testWidgets('Calcula estado En mora cuando existen cuotas atrasadas', (tester) async {
      final overduePayments = [
        PaymentModel(
          id: 'p1',
          policyId: 'pol-100',
          installmentNumber: 1,
          amountUsd: 85.0,
          dueDate: DateTime(2026, 1, 15),
          status: 'atrasado',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: PolicyDetailPage(
            policy: testPolicy,
            onReportError: () {},
            initialPayments: overduePayments,
          ),
        ),
      );

      expect(find.text('En mora'), findsOneWidget);
      expect(find.text('ATRASADO'), findsOneWidget);
    });

    testWidgets('Calcula estado Pagada cuando todas las cuotas estan canceladas', (tester) async {
      final paidPayments = [
        PaymentModel(
          id: 'p1',
          policyId: 'pol-100',
          installmentNumber: 1,
          amountUsd: 85.0,
          dueDate: DateTime(2026, 1, 15),
          paymentDate: DateTime(2026, 1, 10),
          status: 'pagado',
        ),
        PaymentModel(
          id: 'p2',
          policyId: 'pol-100',
          installmentNumber: 2,
          amountUsd: 85.0,
          dueDate: DateTime(2026, 2, 15),
          paymentDate: DateTime(2026, 2, 10),
          status: 'pagado',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: PolicyDetailPage(
            policy: testPolicy,
            onReportError: () {},
            initialPayments: paidPayments,
          ),
        ),
      );

      expect(find.text('Pagada'), findsOneWidget);
      expect(find.text('PAGADO'), findsNWidgets(2));
    });

    testWidgets('Muestra mensaje de sin cuotas cuando la lista esta vacia', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PolicyDetailPage(
            policy: testPolicy,
            onReportError: () {},
            initialPayments: const [],
          ),
        ),
      );

      expect(find.text('No hay cuotas registradas para esta póliza.'), findsOneWidget);
      expect(find.text('Sin cuotas registradas'), findsOneWidget);
    });

    testWidgets('Carga cuotas exitosamente desde cliente HTTP', (tester) async {
      final mockClient = MockHttpClient();
      final responsePayload = jsonEncode([
        {
          'id': 'pago-remote-1',
          'poliza_id': 'pol-100',
          'numero_cuota': 1,
          'monto_usd': 90.0,
          'fecha_vencimiento': '2026-03-01',
          'fecha_pago': '2026-03-01',
          'estado': 'pagado',
          'metodo_pago': 'debito_bancario',
          'comprobante_ref': 'DEB-001',
        }
      ]);

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responsePayload, 200));

      await tester.pumpWidget(
        MaterialApp(
          home: PolicyDetailPage(
            policy: testPolicy,
            onReportError: () {},
            httpClient: mockClient,
            authToken: 'fake-jwt-token',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cuota 1'), findsOneWidget);
      expect(find.text('\$90.00 USD'), findsOneWidget);
      expect(find.text('PAGADO'), findsOneWidget);
    });

    testWidgets('Muestra mensaje de error y boton de reintentar ante fallo de red', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockHttpClient();

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Internal Server Error', 500));

      await tester.pumpWidget(
        MaterialApp(
          home: PolicyDetailPage(
            policy: testPolicy,
            onReportError: () {},
            httpClient: mockClient,
            authToken: 'fake-jwt-token',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No se pudieron cargar las cuotas (500)'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      // Ahora simular que el reintento funciona
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(jsonEncode([]), 200));

      final retryButton = find.text('Reintentar');
      await tester.ensureVisible(retryButton);
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(find.text('No hay cuotas registradas para esta póliza.'), findsOneWidget);
    });

    testWidgets('Boton reportar error dispara callback onReportError', (tester) async {
      bool errorReported = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PolicyDetailPage(
            policy: testPolicy,
            onReportError: () => errorReported = true,
            initialPayments: const [],
          ),
        ),
      );

      final reportButton = find.text('Reportar un error en la póliza');
      await tester.ensureVisible(reportButton);
      await tester.tap(reportButton);
      await tester.pumpAndSettle();

      expect(errorReported, isTrue);
    });
  });
}
