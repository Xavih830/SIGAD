import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/utils/print/reports_html_generator.dart';
import '../helpers/test_factories.dart';

void main() {
  group('ReportsHtmlGenerator Tests (A4 Formatting & KPIs)', () {
    test('Genera reporte ejecutivo en A4 con KPIs consolidados y tabla de pólizas', () {
      final policies = [
        TestFactories.createPolicy(
          number: 'POL-REP-001',
          status: 'activa',
          insuredValue: 20000.0,
          monthlyPremium: 60.0,
        ),
        TestFactories.createPolicy(
          number: 'POL-REP-002',
          status: 'vencida',
          insuredValue: 15000.0,
          monthlyPremium: 45.0,
        ),
      ];

      final html = ReportsHtmlGenerator.generate(
        policies: policies,
        totalCount: 2,
        activeCount: 1,
        expiredCount: 1,
        canceledCount: 0,
        totalInsured: 35000.0,
        totalPremiums: 105.0,
      );

      expect(html, contains('size: A4 portrait;'));
      expect(html, contains('margin: 12mm 15mm;'));
      expect(html, contains('Reporte Ejecutivo de Cartera Vehicular'));
      expect(html, contains('POL-REP-001'));
      expect(html, contains('POL-REP-002'));
      expect(html, contains('\$35000.00'));
      expect(html, contains('\$105.00'));
      expect(html, contains('Vigentes:</strong> 1'));
      expect(html, contains('Vencidas:</strong> 1'));
    });

    test('Escapa caracteres peligrosos en el reporte', () {
      final policies = [
        TestFactories.createPolicy(
          number: '<script>hack()</script>',
          clientId: 'user" onmouseover="alert()',
        ),
      ];

      final html = ReportsHtmlGenerator.generate(
        policies: policies,
        totalCount: 1,
        activeCount: 1,
        expiredCount: 0,
        canceledCount: 0,
        totalInsured: 10000.0,
        totalPremiums: 50.0,
      );

      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;script&gt;hack()&lt;/script&gt;'));
      expect(html, contains('user&quot; onmouseover=&quot;alert()'));
    });
  });
}

