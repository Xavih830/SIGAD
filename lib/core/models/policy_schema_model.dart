class PolicySchemaFieldModel {
  final String nombre;
  final String tipo;
  final bool esObligatorio;
  final int orden;
  final String? formatoFecha;

  const PolicySchemaFieldModel({
    required this.nombre,
    this.tipo = 'texto',
    this.esObligatorio = false,
    this.orden = 0,
    this.formatoFecha,
  });

  factory PolicySchemaFieldModel.fromJson(Map<String, dynamic> json) {
    return PolicySchemaFieldModel(
      nombre: json['nombre'] as String,
      tipo: json['tipo'] as String,
      esObligatorio: json['es_obligatorio'] as bool,
      orden: (json['orden'] as num).toInt(),
      formatoFecha: json['formato_fecha'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'tipo': tipo,
        'es_obligatorio': esObligatorio,
        'orden': orden,
        if (formatoFecha != null) 'formato_fecha': formatoFecha,
      };
}

class PolicySchemaListItemModel {
  final String id;
  final String codigo;
  final String nombre;
  final int version;
  final bool esActivo;
  final DateTime createdAt;

  const PolicySchemaListItemModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.version,
    required this.esActivo,
    required this.createdAt,
  });

  factory PolicySchemaListItemModel.fromJson(Map<String, dynamic> json) {
    return PolicySchemaListItemModel(
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

class PolicySchemaModel {
  final String id;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final int version;
  final bool esActivo;
  final String? creadoPor;
  final DateTime createdAt;
  final List<PolicySchemaFieldModel> campos;

  const PolicySchemaModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    required this.version,
    required this.esActivo,
    this.creadoPor,
    required this.createdAt,
    required this.campos,
  });

  factory PolicySchemaModel.fromJson(Map<String, dynamic> json) {
    final camposList = json['campos'] as List<dynamic>;
    return PolicySchemaModel(
      id: json['id'] as String,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      version: (json['version'] as num).toInt(),
      esActivo: json['es_activo'] as bool,
      creadoPor: json['creado_por'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      campos: camposList
          .map((c) => PolicySchemaFieldModel.fromJson(c as Map<String, dynamic>))
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

class CreatePolicySchemaRequest {
  final String codigo;
  final String nombre;
  final String? descripcion;
  final List<PolicySchemaFieldModel> campos;

  const CreatePolicySchemaRequest({
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
