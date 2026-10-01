/// Modelo de datos canónico para Vehículos en SIGAD.
///
/// Contrato estricto OpenAPI — sin shims de compatibilidad en inglés.
/// Falla-Rápido: si el backend no entrega los campos requeridos, lanza TypeError.
class VehicleModel {
  final String? id;
  final String plate;
  final String brand;
  final String model;
  final int year;
  final String? color;
  final String? type;
  final double? tonnage;
  final String? clientId;

  const VehicleModel({
    this.id,
    required this.plate,
    required this.brand,
    required this.model,
    required this.year,
    this.color,
    this.type,
    this.tonnage,
    this.clientId,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String?,
      plate: json['placa'] as String,
      brand: json['marca'] as String,
      model: json['modelo'] as String,
      year: json['anio'] as int,
      color: json['color'] as String?,
      type: json['tipo'] as String?,
      tonnage: (json['tonelaje'] as num?)?.toDouble(),
      clientId: json['cliente_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'placa': plate,
        'marca': brand,
        'modelo': model,
        'anio': year,
        if (color != null) 'color': color,
        if (type != null) 'tipo': type,
        if (tonnage != null) 'tonelaje': tonnage,
        if (clientId != null) 'cliente_id': clientId,
      };
}
