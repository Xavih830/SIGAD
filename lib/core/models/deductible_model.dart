import 'package:sigad/core/utils/numeric_parser.dart';

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
      porcentajeValor: parseRequiredDouble(json['porcentaje_valor']),
      montoMinimoUsd: parseRequiredDouble(json['monto_minimo_usd']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'tipo_siniestro': tipoSiniestro,
        'porcentaje_valor': porcentajeValor,
        'monto_minimo_usd': montoMinimoUsd,
      };

  Map<String, dynamic> toCreatePayloadJson() => {
        'tipo_siniestro': tipoSiniestro,
        'porcentaje_valor': porcentajeValor,
        'monto_minimo_usd': montoMinimoUsd,
      };
}
