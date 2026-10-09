class ExtractionFieldModel {
  final String nombre;
  final String regex;
  final String tipo;
  final int grupoCaptura;
  final String? formatoFecha;
  final bool esObligatorio;
  final int orden;

  const ExtractionFieldModel({
    required this.nombre,
    required this.regex,
    this.tipo = 'texto',
    this.grupoCaptura = 1,
    this.formatoFecha,
    this.esObligatorio = false,
    this.orden = 0,
  });

  factory ExtractionFieldModel.fromJson(Map<String, dynamic> json) {
    return ExtractionFieldModel(
      nombre: json['nombre'] as String,
      regex: json['regex'] as String,
      tipo: json['tipo'] as String? ?? 'texto',
      grupoCaptura: (json['grupo_captura'] as num?)?.toInt() ?? 1,
      formatoFecha: json['formato_fecha'] as String?,
      esObligatorio: json['es_obligatorio'] as bool? ?? false,
      orden: (json['orden'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'regex': regex,
    'tipo': tipo,
    'grupo_captura': grupoCaptura,
    if (formatoFecha != null) 'formato_fecha': formatoFecha,
    'es_obligatorio': esObligatorio,
    'orden': orden,
  };
}

class ExtractionSchemaListItemModel {
  final String id;
  final String codigo;
  final String nombre;
  final int version;
  final bool esActivo;
  final DateTime createdAt;

  const ExtractionSchemaListItemModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.version,
    required this.esActivo,
    required this.createdAt,
  });

  factory ExtractionSchemaListItemModel.fromJson(Map<String, dynamic> json) {
    return ExtractionSchemaListItemModel(
      id: json['id'] as String,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      version: (json['version'] as num).toInt(),
      esActivo: json['es_activo'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'codigo': codigo,
    'nombre': nombre,
    'version': version,
    'es_activo': esActivo,
    'created_at': createdAt.toIso8601String(),
  };
}

class ExtractionSchemaModel {
  final String id;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final int version;
  final bool esActivo;
  final String? creadoPor;
  final DateTime createdAt;
  final List<ExtractionFieldModel> campos;

  const ExtractionSchemaModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    required this.version,
    required this.esActivo,
    this.creadoPor,
    required this.createdAt,
    this.campos = const [],
  });

  factory ExtractionSchemaModel.fromJson(Map<String, dynamic> json) {
    final camposRaw = json['campos'] as List<dynamic>? ?? [];
    return ExtractionSchemaModel(
      id: json['id'] as String,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      version: (json['version'] as num).toInt(),
      esActivo: json['es_activo'] as bool,
      creadoPor: json['creado_por'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      campos: camposRaw
          .whereType<Map<String, dynamic>>()
          .map((c) => ExtractionFieldModel.fromJson(c))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'codigo': codigo,
    'nombre': nombre,
    if (descripcion != null) 'descripcion': descripcion,
    'version': version,
    'es_activo': esActivo,
    if (creadoPor != null) 'creado_por': creadoPor,
    'created_at': createdAt.toIso8601String(),
    'campos': campos.map((c) => c.toJson()).toList(),
  };
}

class CreateSchemaRequest {
  final String codigo;
  final String nombre;
  final String? descripcion;
  final List<ExtractionFieldModel> campos;

  const CreateSchemaRequest({
    required this.codigo,
    required this.nombre,
    this.descripcion,
    required this.campos,
  });

  Map<String, dynamic> toJson() => {
    'codigo': codigo,
    'nombre': nombre,
    if (descripcion != null) 'descripcion': descripcion,
    'campos': campos.map((c) => c.toJson()).toList(),
  };
}

class TestSchemaResultModel {
  final String metodo;
  final double confianza;
  final Map<String, dynamic> camposExtraidos;
  final String textoCompleto;

  const TestSchemaResultModel({
    required this.metodo,
    required this.confianza,
    required this.camposExtraidos,
    required this.textoCompleto,
  });

  factory TestSchemaResultModel.fromJson(Map<String, dynamic> json) {
    return TestSchemaResultModel(
      metodo: json['metodo'] as String,
      confianza: (json['confianza'] as num).toDouble(),
      camposExtraidos: Map<String, dynamic>.from(json['campos_extraidos'] as Map),
      textoCompleto: json['texto_completo'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'metodo': metodo,
    'confianza': confianza,
    'campos_extraidos': camposExtraidos,
    'texto_completo': textoCompleto,
  };
}
