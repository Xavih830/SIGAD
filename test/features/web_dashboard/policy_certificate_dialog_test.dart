import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/models/extraction_rule_preset.dart';
import 'package:sigad/core/testing/test_factories.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_certificate_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_detail_dialog.dart';

void main() {
  group('ExtractionPresetCatalog Tests', () {
    test('matchPresetFromRegex reconoce expresiones canónicas predefinidas', () {
      final placaPreset = ExtractionPresetCatalog.matchPresetFromRegex(r'(?i)\b([A-Z]{3}-?\d{3,4})\b');
      expect(placaPreset.id, equals('placa_vehicular'));

      final cedulaPreset = ExtractionPresetCatalog.matchPresetFromRegex(r'\b(\d{10}(?:\d{3})?)\b');
      expect(cedulaPreset.id, equals('cedula_ruc'));

      final customPreset = ExtractionPresetCatalog.matchPresetFromRegex(r'[0-9]{5}-[A-Z]');
      expect(customPreset.id, equals('personalizado_regex'));
    });

    test('buildRegex genera patrón con etiqueta y prefijo para texto_tras_etiqueta', () {
      final preset = ExtractionPresetCatalog.textAfterLabel;
      final generated = preset.buildRegex('Asegurado');
      expect(generated, contains('Asegurado'));
      expect(generated, contains(r'\s*[:=]?\s*([^\n\r]+)'));
    });
  });

  group('PolicyCertificateDialog & PolicyDetailDialog Tests', () {
    testWidgets('PolicyCertificateDialog renderiza membrete corporativo y datos del vehículo', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockPolicy = TestFactories.createPolicy(
        number: 'POL-2026-TEST-99',
        status: 'activa',
        insuredValue: 25000.0,
        monthlyPremium: 120.0,
        emissionMileage: 45000,
        vehicle: TestFactories.createVehicle(
          plate: 'PBX-1234',
          brand: 'Chevrolet',
          model: 'D-Max',
          year: 2024,
        ),
        camposAdicionales: {
          'tonelaje_maximo': 3.5,
          'dispositivo_gps': true,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PolicyCertificateDialog(
              policy: mockPolicy,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SIGAD SEGUROS S.A.'), findsOneWidget);
      expect(find.text('RUC: 1792345678001 • Matriz Quito - Ecuador'), findsOneWidget);
      expect(find.text('PÓLIZA N° POL-2026-TEST-99'), findsOneWidget);
      expect(find.text('PBX-1234'), findsOneWidget);
      expect(find.text('Chevrolet'), findsOneWidget);
      expect(find.text('Tonelaje Maximo: '), findsOneWidget);
      expect(find.text('3.5'), findsOneWidget);
      expect(find.text('Dispositivo Gps: '), findsOneWidget);
      expect(find.text('SÍ'), findsOneWidget);
      expect(find.text('Imprimir / Guardar PDF'), findsOneWidget);
    });

    testWidgets('PolicyDetailDialog incluye botón de exportar certificado y campos de esquema', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockPolicy = TestFactories.createPolicy(
        number: 'POL-2026-DETAIL-01',
        status: 'activa',
        insuredValue: 18000.0,
        monthlyPremium: 85.0,
        camposAdicionales: {
          'tipo_carga': 'perecible',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PolicyDetailDialog(
              policy: mockPolicy,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Póliza: POL-2026-DETAIL-01'), findsOneWidget);
      expect(find.text('Especificaciones Específicas del Esquema'), findsOneWidget);
      expect(find.text('Tipo Carga:'), findsOneWidget);
      expect(find.text('perecible'), findsOneWidget);
      expect(find.text('Exportar Certificado'), findsOneWidget);
    });
  });
}

