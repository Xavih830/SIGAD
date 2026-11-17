import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/utils/date_formatter.dart';

/// Generador de documento formal A4 en formato HTML para certificados de pólizas.
class PolicyCertificateHtmlGenerator {
  static String generate({
    required PolicyModel policy,
    String? clientName,
  }) {
    final veh = policy.vehicle;
    final titular = _escape(
      (clientName != null && clientName.trim().isNotEmpty)
          ? clientName.trim()
          : policy.clientId,
    );
    final policyNum = _escape(policy.number);
    final status = _escape(policy.status.toUpperCase());
    final startDate = _escape(DateFormatter.toIsoDate(policy.startDate));
    final endDate = _escape(DateFormatter.toIsoDate(policy.endDate));
    final mileage = '${policy.emissionMileage} KM';

    final plate = _escape(veh?.plate ?? 'S/P');
    final brand = _escape(veh?.brand ?? 'No especificada');
    final model = _escape(veh?.model ?? 'No especificado');
    final year = veh != null ? '${veh.year}' : 'N/A';

    final insuredVal = policy.insuredValue.toStringAsFixed(2);
    final premiumVal = policy.monthlyPremium.toStringAsFixed(2);

    final coveragesHtml = policy.coverages.isEmpty
        ? '<em>Sin coberturas registradas</em>'
        : policy.coverages
            .map((c) =>
                '<span class="badge badge-coverage">&#10004; ${_escape(c.nombre)}</span>')
            .join(' ');

    final deductiblesRows = policy.deductibles.isEmpty
        ? ''
        : policy.deductibles
            .map((d) => '''
          <tr>
            <td>&bull; ${_escape(d.tipoSiniestro.toUpperCase())}</td>
            <td style="text-align: right; font-weight: bold;">
              ${d.porcentajeValor}% (M&iacute;nimo \$${d.montoMinimoUsd.toStringAsFixed(2)} USD)
            </td>
          </tr>
        ''')
            .join('');

    final additionalFieldsHtml = (policy.camposAdicionales != null &&
            policy.camposAdicionales!.isNotEmpty)
        ? _buildAdditionalFields(policy.camposAdicionales!)
        : '';

    return '''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>Certificado de P&oacute;liza $policyNum</title>
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
      font-size: 10pt;
      line-height: 1.35;
      color: #1a202c;
      background: #ffffff;
      padding: 10px;
    }
    .sheet {
      width: 100%;
      max-width: 190mm;
      margin: 0 auto;
    }
    .header-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 12px;
      padding-bottom: 8px;
      border-bottom: 2px solid #003366;
    }
    .header-logo {
      width: 48px;
      height: 48px;
      background: #003366;
      border-radius: 8px;
      color: #ffffff;
      font-size: 24px;
      font-weight: bold;
      text-align: center;
      line-height: 48px;
      display: inline-block;
      vertical-align: middle;
    }
    .header-brand {
      padding-left: 12px;
      vertical-align: middle;
    }
    .header-brand h1 {
      font-size: 16pt;
      color: #003366;
      margin: 0;
      letter-spacing: 0.5px;
    }
    .header-brand p {
      font-size: 8.5pt;
      color: #718096;
      margin: 1px 0;
    }
    .header-policy-box {
      text-align: right;
      vertical-align: middle;
    }
    .policy-pill {
      display: inline-block;
      background: rgba(0, 51, 102, 0.08);
      border: 1px solid #003366;
      color: #003366;
      font-weight: bold;
      font-size: 11pt;
      padding: 4px 10px;
      border-radius: 6px;
    }
    .policy-status {
      font-size: 8.5pt;
      font-weight: 600;
      color: #2d3748;
      margin-top: 4px;
    }
    .doc-title {
      text-align: center;
      font-size: 13pt;
      font-weight: bold;
      letter-spacing: 0.8px;
      color: #1a202c;
      margin: 12px 0 14px 0;
      text-transform: uppercase;
    }
    .section-title {
      background: #edf2f7;
      color: #2d3748;
      font-size: 9pt;
      font-weight: bold;
      padding: 4px 8px;
      border-radius: 4px;
      margin-top: 10px;
      margin-bottom: 6px;
      border-left: 3px solid #003366;
    }
    .data-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 8px;
    }
    .data-table td {
      padding: 3px 6px;
      vertical-align: top;
      font-size: 9.5pt;
    }
    .data-label {
      color: #718096;
      width: 32%;
    }
    .data-value {
      color: #1a202c;
      font-weight: 600;
    }
    .badge {
      display: inline-block;
      padding: 3px 8px;
      border-radius: 4px;
      font-size: 8.5pt;
      margin: 2px 4px 2px 0;
    }
    .badge-coverage {
      background: #f7fafc;
      border: 1px solid #cbd5e0;
      color: #2d3748;
    }
    .signatures-table {
      width: 100%;
      margin-top: 35px;
      border-collapse: collapse;
    }
    .signatures-table td {
      width: 50%;
      text-align: center;
      padding: 0 30px;
    }
    .sig-line {
      border-top: 1px solid #4a5568;
      padding-top: 5px;
      font-size: 9pt;
      font-weight: bold;
      color: #1a202c;
    }
    .sig-sub {
      font-size: 8pt;
      color: #718096;
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
  <div class="sheet">
    <table class="header-table">
      <tr>
        <td style="width: 54px;">
          <div class="header-logo">&#128737;</div>
        </td>
        <td class="header-brand">
          <h1>SIGAD SEGUROS S.A.</h1>
          <p>RUC: 1792345678001 &bull; Matriz Quito - Ecuador</p>
          <p>PBX: (02) 2999-000 &bull; contacto@sigadseguros.com.ec</p>
        </td>
        <td class="header-policy-box">
          <div class="policy-pill">P&Oacute;LIZA N&deg; $policyNum</div>
          <div class="policy-status">Estado: $status</div>
        </td>
      </tr>
    </table>

    <div class="doc-title">Certificado de Cobertura Vehicular</div>

    <div class="section-title">1. DATOS CONTRACTUALES Y VIGENCIA</div>
    <table class="data-table">
      <tr>
        <td class="data-label">Titular / Cliente:</td>
        <td class="data-value">$titular</td>
        <td class="data-label">Emisi&oacute;n Kilometraje:</td>
        <td class="data-value">$mileage</td>
      </tr>
      <tr>
        <td class="data-label">Inicio Vigencia:</td>
        <td class="data-value">$startDate</td>
        <td class="data-label">Fin Vigencia:</td>
        <td class="data-value">$endDate</td>
      </tr>
    </table>

    <div class="section-title">2. ESPECIFICACIONES DEL VEH&Iacute;CULO ASEGURADO</div>
    <table class="data-table">
      <tr>
        <td class="data-label">Placa de Rodaje:</td>
        <td class="data-value">$plate</td>
        <td class="data-label">Modelo:</td>
        <td class="data-value">$model</td>
      </tr>
      <tr>
        <td class="data-label">Marca / Fabricante:</td>
        <td class="data-value">$brand</td>
        <td class="data-label">A&ntilde;o de Fabricaci&oacute;n:</td>
        <td class="data-value">$year</td>
      </tr>
    </table>

    $additionalFieldsHtml

    <div class="section-title">3. CONDICIONES ECON&Oacute;MICAS Y COBERTURAS</div>
    <table class="data-table">
      <tr>
        <td class="data-label">Valor Asegurado Comercial:</td>
        <td class="data-value">\$ $insuredVal USD</td>
        <td class="data-label">Prima Neta Mensual:</td>
        <td class="data-value">\$ $premiumVal USD</td>
      </tr>
    </table>
    <div style="margin: 4px 6px 8px 6px;">
      <div style="font-size: 8.5pt; font-weight: bold; color: #4a5568; margin-bottom: 4px;">Coberturas Contratadas:</div>
      $coveragesHtml
    </div>

    ${deductiblesRows.isNotEmpty ? '''
    <div class="section-title">4. DEDUCIBLES CONTRATADOS</div>
    <table class="data-table" style="margin-top: 4px;">
      $deductiblesRows
    </table>
    ''' : ''}

    <table class="signatures-table">
      <tr>
        <td>
          <div class="sig-line">Asegurador / Emisor Autorizado</div>
          <div class="sig-sub">SIGAD Seguros S.A.</div>
        </td>
        <td>
          <div class="sig-line">Asegurado / Titular</div>
          <div class="sig-sub">Conformidad Contractual</div>
        </td>
      </tr>
    </table>

    <div class="footer-note">
      Documento oficial emitido conforme a las regulaciones de la Superintendencia de Compa&ntilde;&iacute;as, Valores y Seguros del Ecuador.
    </div>
  </div>
</body>
</html>''';
  }

  static String _buildAdditionalFields(Map<String, dynamic> campos) {
    final buffer = StringBuffer();
    buffer.writeln(
        '<div class="section-title">ESPECIFICACIONES T&Eacute;CNICAS ADICIONALES (ESQUEMA VEHICULAR)</div>');
    buffer.writeln('<table class="data-table">');

    final entries = campos.entries.toList();
    for (var i = 0; i < entries.length; i += 2) {
      final e1 = entries[i];
      final key1 = _formatKey(e1.key);
      final val1 = _formatVal(e1.value);

      buffer.writeln('<tr>');
      buffer.writeln('<td class="data-label">$key1:</td>');
      buffer.writeln('<td class="data-value">$val1</td>');

      if (i + 1 < entries.length) {
        final e2 = entries[i + 1];
        final key2 = _formatKey(e2.key);
        final val2 = _formatVal(e2.value);
        buffer.writeln('<td class="data-label">$key2:</td>');
        buffer.writeln('<td class="data-value">$val2</td>');
      } else {
        buffer.writeln(
            '<td class="data-label"></td><td class="data-value"></td>');
      }
      buffer.writeln('</tr>');
    }
    buffer.writeln('</table>');
    return buffer.toString();
  }

  static String _formatKey(String key) {
    return _escape(
      key
          .split('_')
          .map((w) =>
              w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
          .join(' '),
    );
  }

  static String _formatVal(dynamic val) {
    if (val is bool) {
      return val ? 'S&Iacute;' : 'NO';
    }
    return _escape('$val');
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

