import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/utils/print/policy_certificate_html_generator.dart';
import '../helpers/test_factories.dart';

void main() {
  group('PolicyCertificateHtmlGenerator Tests (A4 Formatting & Escaping)', () {
    test('Genera estructura A4 con directiva @page y estiramiento de color de impresión', () {
      final policy = TestFactories.createPolicy(
        number: 'POL-2026-TEST',
        insuredValue: 25000.0,
        monthlyPremium: 75.50,
      );

      final html = PolicyCertificateHtmlGenerator.generate(
        policy: policy,
        clientName: 'Juan Pérez',
      );

      expect(html, contains('size: A4 portrait;'));
      expect(html, contains('margin: 12mm 15mm;'));
      expect(html, contains('-webkit-print-color-adjust: exact'));
      expect(html, contains('SIGAD SEGUROS S.A.'));
      expect(html, contains('POL-2026-TEST'));
      expect(html, contains('Juan Pérez'));
      expect(html, contains('25000.00'));
      expect(html, contains('75.50'));
    });

    test('Escapa caracteres HTML para mitigar inyecciones XSS', () {
      final policy = TestFactories.createPolicy(
        number: 'POL<script>alert(1)</script>',
      );

      final html = PolicyCertificateHtmlGenerator.generate(
        policy: policy,
        clientName: 'Empresa & Asociados <evil>',
      );

      expect(html, isNot(contains('<script>')));
      expect(html, contains('POL&lt;script&gt;alert(1)&lt;/script&gt;'));
      expect(html, contains('Empresa &amp; Asociados &lt;evil&gt;'));
    });

    test('Renderiza campos adicionales dinámicos del esquema vehicular', () {
      final policy = TestFactories.createPolicy(
        number: 'POL-CUSTOM-001',
        vehicle: TestFactories.createVehicle(
          plate: 'ABC-1234',
          brand: 'Toyota',
          model: 'Hilux',
          year: 2024,
        ),
        insuredValue: 32000.0,
        monthlyPremium: 110.0,
        emissionMileage: 5000,
        deductibles: [
          TestFactories.createDeductible(
            tipoSiniestro: 'perdida_total',
            porcentajeValor: 10,
            montoMinimoUsd: 500.0,
          ),
        ],
        coverages: [
          TestFactories.createCoverage(nombre: 'Responsabilidad Civil'),
        ],
        camposAdicionales: {
          'tipo_combustible': 'Diesel',
          'rastreo_satelital': true,
        },
      );

      final html = PolicyCertificateHtmlGenerator.generate(policy: policy);

      expect(html, contains('ESPECIFICACIONES T&Eacute;CNICAS ADICIONALES'));
      expect(html, contains('Tipo Combustible:'));
      expect(html, contains('Diesel'));
      expect(html, contains('Rastreo Satelital:'));
      expect(html, contains('S&Iacute;'));
      expect(html, contains('Responsabilidad Civil'));
      expect(html, contains('PERDIDA_TOTAL'));
    });
  });
}
