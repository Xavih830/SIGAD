import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sigad/features/mobile_client/presentation/pages/policy_detail_page.dart';
import 'package:sigad/core/testing/test_fixtures.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  final testPolicy = TestFixtures.activePolicy;

  group('HU-20: PolicyDetailPage Widget Tests', () {
    testWidgets('Renderiza desglose real de cuotas y estado financiero Al día', (tester) async {
      final payments = [
        TestFixtures.paidPayment,
        TestFixtures.pendingPayment,
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

      expect(find.text(testPolicy.number), findsOneWidget);
      expect(find.text('Cronograma de Pagos y Cuotas'), findsOneWidget);
      expect(find.text('Al día'), findsOneWidget);

      expect(find.text('Cuota 1'), findsOneWidget);
      expect(find.text('PAGADO'), findsOneWidget);
      expect(find.textContaining(TestFixtures.paidPayment.receiptRef!), findsOneWidget);

      expect(find.text('Cuota 2'), findsOneWidget);
      expect(find.text('PENDIENTE'), findsOneWidget);
      expect(find.text('\$${testPolicy.monthlyPremium.toStringAsFixed(2)} USD'), findsNWidgets(3));
    });

    testWidgets('Calcula estado En mora cuando existen cuotas atrasadas', (tester) async {
      final overduePayments = [
        TestFixtures.overduePayment,
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
        TestFixtures.paidPayment,
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
      expect(find.text('PAGADO'), findsOneWidget);
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
      final responsePayload = jsonEncode([TestFixtures.paidPaymentJson]);

      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(responsePayload, 200));

      await tester.pumpWidget(
        MaterialApp(
          home: PolicyDetailPage(
            policy: testPolicy,
            onReportError: () {},
            httpClient: mockClient,
            authToken: TestFixtures.validToken,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cuota 1'), findsOneWidget);
      expect(find.text('\$${testPolicy.monthlyPremium.toStringAsFixed(2)} USD'), findsNWidgets(2));
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
            authToken: TestFixtures.validToken,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No se pudieron cargar las cuotas (500)'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

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
