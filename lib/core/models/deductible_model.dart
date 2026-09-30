class DeductibleModel {
  final String? id;
  final String coverageName;
  final double percentage;
  final double minAmount;

  const DeductibleModel({
    this.id,
    required this.coverageName,
    required this.percentage,
    required this.minAmount,
  });

  factory DeductibleModel.fromJson(Map<String, dynamic> json) {
    return DeductibleModel(
      id: json['id']?.toString(),
      coverageName: json['nombre_cobertura'] ??
          json['tipo_siniestro'] ??
          json['coverageName'] ??
          json['nombre'] ??
          '',
      percentage: (json['porcentaje'] as num?)?.toDouble() ??
          (json['porcentaje_valor'] as num?)?.toDouble() ??
          (json['percentage'] as num?)?.toDouble() ??
          0.0,
      minAmount: (json['monto_minimo'] as num?)?.toDouble() ??
          (json['monto_minimo_usd'] as num?)?.toDouble() ??
          (json['minAmount'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'nombre_cobertura': coverageName,
    'porcentaje': percentage,
    'monto_minimo': minAmount,
  };
}
