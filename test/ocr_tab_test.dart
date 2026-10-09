import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sigad/core/constants/app_constants.dart';
import 'package:sigad/core/network/api_client.dart';
import 'package:sigad/core/repositories/documents_repository.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/ocr_document_detail_card.dart';
import 'helpers/test_factories.dart';
import 'helpers/test_fixtures.dart';

void main() {
  group('HU-06: OcrDocumentDetailCard Widget & Revision Tests', () {
    final sampleDocument = TestFixtures.ocrDocumentModel;

    testWidgets('Muestra campos extraidos editables con valores precargados', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrDocumentDetailCard(
              document: sampleDocument,
              isLoading: false,
              onRefresh: () {},
              onLinkPolicy: (_) {},
              authToken: TestFixtures.validToken,
            ),
          ),
        ),
      );

      expect(find.text(TestFixtures.ocrSampleFilename), findsOneWidget);
      expect(find.text('REQUIERE_REVISION_MANUAL'), findsOneWidget);
      expect(find.textContaining('CONFIANZA MEDIA (78.5%)'), findsOneWidget);

      final campos = sampleDocument.camposExtraidos!;
      expect(find.text(campos['placa'] as String), findsOneWidget);
      expect(find.text(campos['valor_asegurado'] as String), findsOneWidget);
      expect(find.text(campos['prima_mensual'] as String), findsOneWidget);
      expect(find.text(campos['numero_poliza'] as String), findsOneWidget);

      expect(find.text('Confirmar Correcciones'), findsOneWidget);
      expect(find.text('Vincular a Póliza'), findsOneWidget);
    });

    testWidgets('Permite editar un campo y pasar los datos corregidos a onLinkPolicy', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, dynamic>? capturedFields;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrDocumentDetailCard(
              document: sampleDocument,
              isLoading: false,
              onRefresh: () {},
              onLinkPolicy: (fields) {
                capturedFields = fields;
              },
              authToken: TestFixtures.validToken,
            ),
          ),
        ),
      );

      final campos = sampleDocument.camposExtraidos!;
      final placaField = find.widgetWithText(TextFormField, campos['placa'] as String);
      expect(placaField, findsOneWidget);

      await tester.enterText(placaField, 'GYE-9999');
      await tester.pump();

      final vincularBtn = find.text('Vincular a Póliza');
      await tester.tap(vincularBtn);
      await tester.pump();

      expect(capturedFields, isNotNull);
      expect(capturedFields!['placa'], equals('GYE-9999'));
      expect(capturedFields!['valor_asegurado'], equals(campos['valor_asegurado']));
      expect(capturedFields!['numero_poliza'], equals(campos['numero_poliza']));
    });

    test('Lógica de parseo robusto para vinculación a PolicyModel', () {
      final Map<String, dynamic> rawCampos = {
        'valor_asegurado': r'$ 22,500.00',
        'prima_mensual': r'55.75 USD',
        'kilometraje': '45,200 km',
        'numero_poliza': 'POL-EC-2026-001',
      };

      final double valorAsegurado = double.tryParse(
            rawCampos['valor_asegurado']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
          ) ??
          AppConstants.ocrDefaultInsuredValue;

      final double primaMensual = double.tryParse(
            rawCampos['prima_mensual']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
          ) ??
          AppConstants.ocrDefaultMonthlyPremium;

      final int kilometraje = int.tryParse(
            rawCampos['kilometraje']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '',
          ) ??
          AppConstants.ocrDefaultEmissionMileage;

      final String numeroPoliza = rawCampos['numero_poliza']!.toString();

      final model = TestFactories.createPolicy(
        id: 'pol-1',
        number: numeroPoliza,
        clientId: 'cli-1',
        vehicleId: 'veh-1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2027, 1, 1),
        status: 'activa',
        insuredValue: valorAsegurado,
        monthlyPremium: primaMensual,
        emissionMileage: kilometraje,
      );

      expect(model.insuredValue, equals(22500.00));
      expect(model.monthlyPremium, equals(55.75));
      expect(model.emissionMileage, equals(45200));
      expect(model.number, equals('POL-EC-2026-001'));
    });

    testWidgets('Boton Descargar Documento invoca downloadDocumentBytes en DocumentsRepository', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool downloadCalled = false;
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('/descargar')) {
          downloadCalled = true;
          return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
        }
        return http.Response('{}', 200);
      });

      final customRepo = DocumentsRepository(
        client: ApiClient(client: mockHttpClient, baseUrl: TestFixtures.testBaseUrl),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrDocumentDetailCard(
              document: sampleDocument,
              isLoading: false,
              onRefresh: () {},
              onLinkPolicy: (_) {},
              authToken: TestFixtures.validToken,
              documentsRepository: customRepo,
            ),
          ),
        ),
      );

      final downloadBtn = find.text('Descargar Documento');
      expect(downloadBtn, findsOneWidget);

      await tester.tap(downloadBtn);
      await tester.pump();

      expect(downloadCalled, isTrue);
    });
  });
}
