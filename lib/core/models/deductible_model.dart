/// Modelo canónico para Deducibles en SIGAD.
///
/// Contrato estricto OpenAPI — sin shims ni fallbacks silenciosos.
/// Claves canonicas backend: tipo_siniestro, porcentaje_valor, monto_minimo_usd.
class DeductibleModel {
  final String? id;
  final String tipoSiniestro;
  final double porcentajeValor;
  final double montoMinimoUsd;

  const DeductibleModel({
    this.id,
    required this.tipoSiniestro,
    required this.porcentajeValor,
    required this.montoMinimoUsd,
  });

  factory DeductibleModel.fromJson(Map<String, dynamic> json) {
    return DeductibleModel(
      id: json['id'] as String?,
      tipoSiniestro: json['tipo_siniestro'] as String,
      porcentajeValor: (json['porcentaje_valor'] as num).toDouble(),
      montoMinimoUsd: (json['monto_minimo_usd'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'tipo_siniestro': tipoSiniestro,
        'porcentaje_valor': porcentajeValor,
        'monto_minimo_usd': montoMinimoUsd,
      };
}
