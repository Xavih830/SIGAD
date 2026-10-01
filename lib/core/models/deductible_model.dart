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
      percentage: double.tryParse(
            json['porcentaje']?.toString() ??
                json['porcentaje_valor']?.toString() ??
                json['percentage']?.toString() ??
                '',
          ) ??
          0.0,
      minAmount: double.tryParse(
            json['monto_minimo']?.toString() ??
                json['monto_minimo_usd']?.toString() ??
                json['minAmount']?.toString() ??
                '',
          ) ??
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
