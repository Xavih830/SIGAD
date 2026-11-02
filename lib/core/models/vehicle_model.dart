import 'package:sigad/core/utils/numeric_parser.dart';

class VehicleModel {
  final String? id;
  final String plate;
  final String brand;
  final String model;
  final int year;
  final String? motor;
  final String? chasis;
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
    this.motor,
    this.chasis,
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
      motor: json['motor'] as String?,
      chasis: json['chasis'] as String?,
      color: json['color'] as String?,
      type: json['tipo_placa'] as String?,
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
        if (motor != null) 'motor': motor,
        if (chasis != null) 'chasis': chasis,
        if (color != null) 'color': color,
        if (type != null) 'tipo_placa': type,
        if (tonnage != null) 'tonelaje': tonnage,
        if (clientId != null) 'cliente_id': clientId,
      };
}

class CreateVehicleRequest {
  final String plate;
  final String brand;
  final String model;
  final int year;
  final String motor;
  final String chasis;
  final String color;
  final String clientId;

  const CreateVehicleRequest({
    required this.plate,
    required this.brand,
    required this.model,
    required this.year,
    required this.motor,
    required this.chasis,
    required this.color,
    required this.clientId,
  });

  Map<String, dynamic> toJson() => {
        'placa': plate,
        'marca': brand,
        'modelo': model,
        'anio': year,
        'motor': motor,
        'chasis': chasis,
        'color': color,
        'cliente_id': clientId,
      };
}

class UpdateVehicleRequest {
  final String? brand;
  final String? model;
  final int? year;
  final String? motor;
  final String? chasis;
  final String? color;

  const UpdateVehicleRequest({
    this.brand,
    this.model,
    this.year,
    this.motor,
    this.chasis,
    this.color,
  });

  Map<String, dynamic> toJson() => {
        if (brand != null) 'marca': brand,
        if (model != null) 'modelo': model,
        if (year != null) 'anio': year,
        if (motor != null) 'motor': motor,
        if (chasis != null) 'chasis': chasis,
        if (color != null) 'color': color,
      };
}

