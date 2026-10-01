import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/ocr_document_detail_card.dart';

void main() {
  group('HU-06: OcrDocumentDetailCard Widget & Revision Tests', () {
    final sampleDocument = {
      'id': 'd1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
      'nombre_archivo': 'poliza_contrato_ejemplo.pdf',
      'tipo_mime': 'application/pdf',
      'tamano_bytes': 204800,
      'estado_extraccion': 'requiere_revision_manual',
      'resultado': {
        'metodo': 'tesseract_200dpi',
        'confianza': 78.5,
        'campos_extraidos': {
          'placa': 'PBX-1234',
          'valor_asegurado': '18500.00',
          'prima_mensual': '45.50',
          'numero_poliza': 'POL-OCR-9999',
          'kilometraje': '12500',
        },
        'texto_completo': 'CONTRATO DE SEGURO VEHICULAR PLACA PBX-1234',
      },
    };

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
              authToken: 'test_token',
            ),
          ),
        ),
      );

      // Verificar que se renderiza el nombre del archivo y badges
      expect(find.text('poliza_contrato_ejemplo.pdf'), findsOneWidget);
      expect(find.text('REQUIERE_REVISION_MANUAL'), findsOneWidget);
      expect(find.textContaining('CONFIANZA MEDIA (78.5%)'), findsOneWidget);

      // Verificar que los campos aparecen como inputs editables
      expect(find.text('PBX-1234'), findsOneWidget);
      expect(find.text('18500.00'), findsOneWidget);
      expect(find.text('45.50'), findsOneWidget);
      expect(find.text('POL-OCR-9999'), findsOneWidget);

      // Verificar botones de acción
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
              authToken: 'test_token',
            ),
          ),
        ),
      );

      // Localizar el campo de texto de la placa y modificarlo
      final placaField = find.widgetWithText(TextFormField, 'PBX-1234');
      expect(placaField, findsOneWidget);

      await tester.enterText(placaField, 'GYE-9999');
      await tester.pump();

      // Pulsar el botón 'Vincular a Póliza'
      final vincularBtn = find.text('Vincular a Póliza');
      await tester.tap(vincularBtn);
      await tester.pump();

      // Validar que el callback recibió el valor corregido
      expect(capturedFields, isNotNull);
      expect(capturedFields!['placa'], equals('GYE-9999'));
      expect(capturedFields!['valor_asegurado'], equals('18500.00'));
      expect(capturedFields!['numero_poliza'], equals('POL-OCR-9999'));
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
          15000.0;

      final double primaMensual = double.tryParse(
            rawCampos['prima_mensual']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
          ) ??
          35.0;

      final int kilometraje = int.tryParse(
            rawCampos['kilometraje']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '',
          ) ??
          5000;

      final String numeroPoliza = rawCampos['numero_poliza']!.toString();

      final model = PolicyModel(
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
  });
}
