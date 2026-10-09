import 'package:sigad/core/utils/numeric_parser.dart';

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
      tonnage: parseOptionalDouble(json['tonelaje']),
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
