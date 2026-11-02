import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/utils/date_formatter.dart';

/// Generador de documento formal A4 en formato HTML para reportes ejecutivos.
class ReportsHtmlGenerator {
  static String generate({
    required List<PolicyModel> policies,
    required int totalCount,
    required int activeCount,
    required int expiredCount,
    required int canceledCount,
    required double totalInsured,
    required double totalPremiums,
  }) {
    final emissionDate = DateFormatter.toIsoDate(DateTime.now());

    final policyRows = policies.map((p) {
      final num = _escape(p.number);
      final client = _escape(p.clientId);
      final plate = _escape(p.vehicle?.plate ?? 'S/P');
      final vehicleDesc = _escape(
        p.vehicle != null ? '${p.vehicle!.brand} ${p.vehicle!.model}' : 'N/A',
      );
      final insured = '\$${p.insuredValue.toStringAsFixed(2)}';
      final premium = '\$${p.monthlyPremium.toStringAsFixed(2)}';
      final status = _escape(p.status.toUpperCase());
      final end = _escape(DateFormatter.toIsoDate(p.endDate));

      return '''
        <tr>
          <td><strong>$num</strong></td>
          <td>$client</td>
          <td>$plate</td>
          <td>$vehicleDesc</td>
          <td style="text-align: right;">$insured</td>
          <td style="text-align: right;">$premium</td>
          <td>$end</td>
          <td><span class="status-badge status-${p.status.toLowerCase()}">$status</span></td>
        </tr>
      ''';
    }).join('');

    return '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>Reporte de Cartera Vehicular - SIGAD</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 12mm 15mm;
    }
    @media print {
      body {
        -webkit-print-color-adjust: exact !important;
        print-color-adjust: exact !important;
      }
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
      font-size: 9pt;
      line-height: 1.35;
      color: #1a202c;
      background: #ffffff;
      padding: 10px;
    }
    .header-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 16px;
      border-bottom: 2px solid #003366;
      padding-bottom: 8px;
    }
    .header-brand h1 {
      font-size: 15pt;
      color: #003366;
      margin: 0;
    }
    .header-brand p {
      font-size: 8.5pt;
      color: #718096;
      margin: 1px 0;
    }
    .report-date {
      text-align: right;
      font-size: 8.5pt;
      color: #718096;
    }
    .kpi-grid {
      display: table;
      width: 100%;
      margin-bottom: 16px;
    }
    .kpi-cell {
      display: table-cell;
      width: 25%;
      padding: 8px 10px;
      border: 1px solid #e2e8f0;
      background: #f7fafc;
      border-radius: 6px;
    }
    .kpi-title {
      font-size: 7.5pt;
      text-transform: uppercase;
      color: #718096;
      font-weight: bold;
    }
    .kpi-val {
      font-size: 13pt;
      font-weight: bold;
      color: #003366;
      margin-top: 2px;
    }
    .section-title {
      font-size: 10pt;
      font-weight: bold;
      color: #2d3748;
      margin: 14px 0 6px 0;
      border-bottom: 1px solid #e2e8f0;
      padding-bottom: 4px;
    }
    .report-table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 6px;
      font-size: 8.5pt;
    }
    .report-table th {
      background: #edf2f7;
      color: #2d3748;
      text-align: left;
      padding: 5px 6px;
      border-bottom: 2px solid #cbd5e0;
      font-size: 8pt;
      text-transform: uppercase;
    }
    .report-table td {
      padding: 4px 6px;
      border-bottom: 1px solid #edf2f7;
    }
    .status-badge {
      display: inline-block;
      padding: 2px 6px;
      border-radius: 4px;
      font-size: 7.5pt;
      font-weight: bold;
    }
    .status-activa {
      background: #def7ec;
      color: #03543f;
    }
    .status-vencida {
      background: #feecdc;
      color: #9c4221;
    }
    .status-cancelada {
      background: #fde8e8;
      color: #9b1c1c;
    }
    .footer-note {
      text-align: center;
      font-size: 7.5pt;
      color: #a0aec0;
      margin-top: 24px;
      padding-top: 8px;
      border-top: 1px dashed #e2e8f0;
    }
  </style>
</head>
<body>
  <table class="header-table">
    <tr>
      <td class="header-brand">
        <h1>SIGAD SEGUROS S.A.</h1>
        <p>Reporte Ejecutivo de Cartera Vehicular y Control Operativo</p>
      </td>
      <td class="report-date">
        <strong>Fecha de Emisi&oacute;n:</strong> $emissionDate<br>
        <strong>Total Registros:</strong> $totalCount
      </td>
    </tr>
  </table>

  <div class="kpi-grid">
    <div class="kpi-cell" style="border-left: 3px solid #3182ce;">
      <div class="kpi-title">Total P&oacute;lizas</div>
      <div class="kpi-val">$totalCount</div>
    </div>
    <div class="kpi-cell" style="border-left: 3px solid #38a169;">
      <div class="kpi-title">P&oacute;lizas Activas</div>
      <div class="kpi-val">$activeCount</div>
    </div>
    <div class="kpi-cell" style="border-left: 3px solid #805ad5;">
      <div class="kpi-title">Capital Asegurado</div>
      <div class="kpi-val">\$${totalInsured.toStringAsFixed(2)}</div>
    </div>
    <div class="kpi-cell" style="border-left: 3px solid #319795;">
      <div class="kpi-title">Primas Mensuales</div>
      <div class="kpi-val">\$${totalPremiums.toStringAsFixed(2)}</div>
    </div>
  </div>

  <div class="section-title">Desglose de Cartera por Estado</div>
  <table style="width: 100%; border-collapse: collapse; margin-bottom: 12px; font-size: 8.5pt;">
    <tr>
      <td style="padding: 4px;">&bull; <strong>Vigentes:</strong> $activeCount</td>
      <td style="padding: 4px;">&bull; <strong>Vencidas:</strong> $expiredCount</td>
      <td style="padding: 4px;">&bull; <strong>Canceladas:</strong> $canceledCount</td>
    </tr>
  </table>

  <div class="section-title">Detalle Consolidado de P&oacute;lizas</div>
  <table class="report-table">
    <thead>
      <tr>
        <th>N&deg; P&oacute;liza</th>
        <th>Titular ID</th>
        <th>Placa</th>
        <th>Veh&iacute;culo</th>
        <th style="text-align: right;">Valor Aseg.</th>
        <th style="text-align: right;">Prima</th>
        <th>Vence</th>
        <th>Estado</th>
      </tr>
    </thead>
    <tbody>
      $policyRows
    </tbody>
  </table>

  <div class="footer-note">
    SIGAD - Sistema Integral de Gesti&oacute;n y An&aacute;lisis Documental &bull; Documento Oficial del Sistema
  </div>
</body>
</html>''';
  }

  static String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

