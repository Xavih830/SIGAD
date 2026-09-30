class VehicleModel {
  final String? id;
  final String plate;
  final String brand;
  final String model;
  final int year;
  final String? color;
  final String? type;
  final double? tonnage;

  const VehicleModel({
    this.id,
    required this.plate,
    required this.brand,
    required this.model,
    required this.year,
    this.color,
    this.type,
    this.tonnage,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id']?.toString(),
      plate: json['placa'] ?? json['plate'] ?? '',
      brand: json['marca'] ?? json['brand'] ?? '',
      model: json['modelo'] ?? json['model'] ?? '',
      year: json['anio'] is int
          ? json['anio']
          : int.tryParse(json['anio']?.toString() ?? '2020') ?? 2020,
      color: json['color']?.toString(),
      type: json['tipo'] ?? json['type'],
      tonnage: (json['tonelaje'] as num?)?.toDouble() ?? (json['tonnage'] as num?)?.toDouble(),
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
  };
}
