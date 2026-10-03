/// Modelo canónico fuertemente tipado para Documentos y Extracción OCR en SIGAD.
/// 
/// Contrato OpenAPI estricto: id, poliza_id, nombre_archivo, tipo_mime,
/// tamano_bytes, estado_extraccion, created_at, campos_extraidos.
class DocumentModel {
  final String id;
  final String? polizaId;
  final String nombreArchivo;
  final String tipoMime;
  final int tamanoBytes;
  final String estadoExtraccion;
  final bool hasResultado;
  final DateTime createdAt;
  final Map<String, dynamic>? camposExtraidos;

  const DocumentModel({
    required this.id,
    this.polizaId,
    required this.nombreArchivo,
    required this.tipoMime,
    required this.tamanoBytes,
    required this.estadoExtraccion,
    this.hasResultado = false,
    required this.createdAt,
    this.camposExtraidos,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? campos;
    if (json['resultado'] is Map<String, dynamic>) {
      final res = json['resultado'] as Map<String, dynamic>;
      if (res['campos_extraidos'] is Map<String, dynamic>) {
        campos = Map<String, dynamic>.from(res['campos_extraidos'] as Map);
      }
    } else if (json['campos_extraidos'] is Map<String, dynamic>) {
      campos = Map<String, dynamic>.from(json['campos_extraidos'] as Map);
    }

    return DocumentModel(
      id: json['id'] as String,
      polizaId: json['poliza_id'] as String?,
      nombreArchivo: json['nombre_archivo'] as String,
      tipoMime: (json['tipo_mime'] ?? 'application/pdf') as String,
      tamanoBytes: (json['tamano_bytes'] as num?)?.toInt() ?? 0,
      estadoExtraccion: json['estado_extraccion'] as String,
      hasResultado: json['has_resultado'] == true || json['resultado'] != null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      camposExtraidos: campos,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (polizaId != null) 'poliza_id': polizaId,
        'nombre_archivo': nombreArchivo,
        'tipo_mime': tipoMime,
        'tamano_bytes': tamanoBytes,
        'estado_extraccion': estadoExtraccion,
        'has_resultado': hasResultado,
        'created_at': createdAt.toIso8601String(),
        if (camposExtraidos != null) 'campos_extraidos': camposExtraidos,
      };
}
