/// Preset semántico de extracción amigable para usuarios no técnicos.
/// Traduce patrones semánticos comunes (placa, cédula, monto, fecha, etc.)
/// en expresiones regulares robustas sin que el usuario tenga que escribirlas.
class ExtractionRulePreset {
  final String id;
  final String label;
  final String tipoDato;
  final String regexPattern;
  final String descripcion;
  final String ejemplo;
  final bool requiresKeyword;

  const ExtractionRulePreset({
    required this.id,
    required this.label,
    required this.tipoDato,
    required this.regexPattern,
    required this.descripcion,
    required this.ejemplo,
    this.requiresKeyword = false,
  });

  /// Construye el patrón regex final considerando si requiere prefijo/etiqueta cercana.
  String buildRegex([String? keyword]) {
    if (!requiresKeyword) {
      return regexPattern;
    }
    final cleanKeyword = (keyword ?? '').trim();
    if (cleanKeyword.isEmpty) {
      return regexPattern;
    }
    final escapedKeyword = RegExp.escape(cleanKeyword);
    return r'(?i)' + escapedKeyword + r'\s*[:=]?\s*([^\n\r]+)';
  }
}

/// Catálogo de reglas semánticas predefinidas para aseguradoras y pólizas vehiculares.
abstract class ExtractionPresetCatalog {
  static const ExtractionRulePreset plateEcuador = ExtractionRulePreset(
    id: 'placa_vehicular',
    label: 'Placa Vehicular (Ecuador)',
    tipoDato: 'texto',
    regexPattern: r'(?i)\b([A-Z]{3}-?\d{3,4})\b',
    descripcion: 'Identifica placas automotrices como PBX-1234 o ABC-123.',
    ejemplo: 'PBC-4589',
  );

  static const ExtractionRulePreset ecuadorianId = ExtractionRulePreset(
    id: 'cedula_ruc',
    label: 'Cédula o RUC',
    tipoDato: 'texto',
    regexPattern: r'\b(\d{10}(?:\d{3})?)\b',
    descripcion: 'Identifica números de cédula (10 dígitos) o RUC (13 dígitos).',
    ejemplo: '1710034065 o 1790012345001',
  );

  static const ExtractionRulePreset currencyAmount = ExtractionRulePreset(
    id: 'monto_moneda',
    label: 'Monto / Valor Monetario (\$ USD)',
    tipoDato: 'decimal',
    regexPattern: r'\$?\s*(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|\d+(?:[.,]\d{2}))',
    descripcion: 'Captura valores monetarios con formato decimal estándar.',
    ejemplo: '\$ 1,250.50 o 450.00',
  );

  static const ExtractionRulePreset standardDate = ExtractionRulePreset(
    id: 'fecha_estandar',
    label: 'Fecha (DD/MM/AAAA o AAAA-MM-DD)',
    tipoDato: 'fecha',
    regexPattern: r'\b(\d{2}[/-]\d{2}[/-]\d{4}|\d{4}[/-]\d{2}[/-]\d{2})\b',
    descripcion: 'Captura fechas de inicio, fin o emisión de vigencia.',
    ejemplo: '15/10/2026 o 2026-10-15',
  );

  static const ExtractionRulePreset vinChassis = ExtractionRulePreset(
    id: 'numero_chasis_vin',
    label: 'Número de Chasis / VIN',
    tipoDato: 'texto',
    regexPattern: r'\b([A-HJ-NPR-Z0-9]{17})\b',
    descripcion: 'Código alfanumérico VIN de 17 caracteres estándar.',
    ejemplo: '1HGCR2F83HA123456',
  );

  static const ExtractionRulePreset policyCode = ExtractionRulePreset(
    id: 'codigo_poliza',
    label: 'Número de Póliza / Contrato',
    tipoDato: 'texto',
    regexPattern: r'(?i)(?:poliza|póliza|poliza\s*n[°o]?)\s*[:=]?\s*([A-Z0-9\-_/]{4,25})',
    descripcion: 'Extrae códigos alfanuméricos de póliza posterior a la palabra clave.',
    ejemplo: 'POL-2026-88912',
  );

  static const ExtractionRulePreset textAfterLabel = ExtractionRulePreset(
    id: 'texto_tras_etiqueta',
    label: 'Texto después de una etiqueta clave',
    tipoDato: 'texto',
    regexPattern: r'(?i)(?:campo)\s*[:=]?\s*([^\n\r]+)',
    descripcion: 'Extrae el texto que aparezca a la derecha de una palabra específica.',
    ejemplo: 'Asegurado: Juan Pérez',
    requiresKeyword: true,
  );

  static const ExtractionRulePreset customRegex = ExtractionRulePreset(
    id: 'personalizado_regex',
    label: 'Regla Técnica Avanzada (Regex manual)',
    tipoDato: 'texto',
    regexPattern: '',
    descripcion: 'Permite a administradores técnicos especificar un regex crudo.',
    ejemplo: r'(?:ID):\s*([0-9]+)',
  );

  static const List<ExtractionRulePreset> allPresets = [
    plateEcuador,
    ecuadorianId,
    currencyAmount,
    standardDate,
    vinChassis,
    policyCode,
    textAfterLabel,
    customRegex,
  ];

  static ExtractionRulePreset findById(String id) {
    for (final preset in allPresets) {
      if (preset.id == id) return preset;
    }
    return customRegex;
  }

  static ExtractionRulePreset matchPresetFromRegex(String regex) {
    final trimmed = regex.trim();
    for (final preset in allPresets) {
      if (preset.id != 'personalizado_regex' && !preset.requiresKeyword && preset.regexPattern == trimmed) {
        return preset;
      }
    }
    if (trimmed.startsWith(r'(?i)') && trimmed.contains(r'\s*[:=]?\s*([^\n\r]+)')) {
      return textAfterLabel;
    }
    return customRegex;
  }

  static String extractKeywordFromTextAfterLabel(String regex) {
    final match = RegExp(r'\(\?i\)(.+?)\\s\*\[:=\]\?\\s\*').firstMatch(regex);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.replaceAll(r'\', '') ?? '';
    }
    return '';
  }
}

