import 'package:sigad/core/models/deductible_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';

class PolicyModel {
  final String id;
  final String number;
  final String clientId;
  final String vehicleId;
  final VehicleModel? vehicle;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'activa', 'vencida', 'cancelada'
  final double insuredValue;
  final double monthlyPremium;
  final int emissionMileage;
  final List<DeductibleModel> deductibles;
  final List<String> coverages;
  final String? clientName;
  final String? paymentStatus;
  final String? lastPaymentDate;

  const PolicyModel({
    required this.id,
    required this.number,
    required this.clientId,
    required this.vehicleId,
    this.vehicle,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.insuredValue,
    required this.monthlyPremium,
    required this.emissionMileage,
    this.deductibles = const [],
    this.coverages = const [],
    this.clientName,
    this.paymentStatus,
    this.lastPaymentDate,
  });

  // Getters de Negocio Puros (Anti-Tangling en Widgets)
  int get daysUntilExpiration => endDate.difference(DateTime.now()).inDays;
  bool get isExpired => DateTime.now().isAfter(endDate) || status.toLowerCase() == 'vencida';
  bool get isExpiringSoon => !isExpired && daysUntilExpiration <= 30 && daysUntilExpiration >= 0;

  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    VehicleModel? veh;
    if (json['vehiculo'] is Map<String, dynamic>) {
      veh = VehicleModel.fromJson(json['vehiculo'] as Map<String, dynamic>);
    } else if (json['plate'] != null || json['placa'] != null) {
      veh = VehicleModel.fromJson(json);
    }

    final dedsList = json['deducibles'] as List<dynamic>? ?? [];
    final deds = dedsList
        .whereType<Map<String, dynamic>>()
        .map((d) => DeductibleModel.fromJson(d))
        .toList();

    final covsList = json['coberturas'] as List<dynamic>? ?? [];
    final covs = covsList.map((c) {
      if (c is Map) return c['nombre']?.toString() ?? '';
      return c.toString();
    }).where((c) => c.isNotEmpty).toList();

    return PolicyModel(
      id: json['id']?.toString() ?? '',
      number: json['numero_poliza'] ?? json['number'] ?? '',
      clientId: json['cliente_id']?.toString() ?? json['clientId']?.toString() ?? '',
      vehicleId: json['vehiculo_id']?.toString() ?? json['vehicleId']?.toString() ?? '',
      vehicle: veh,
      startDate: DateTime.tryParse(json['fecha_inicio']?.toString() ?? json['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['fecha_fin']?.toString() ?? json['endDate']?.toString() ?? '') ?? DateTime.now(),
      status: json['estado'] ?? json['status'] ?? 'activa',
      insuredValue: double.tryParse(
            json['valor_asegurado']?.toString() ??
                json['value']?.toString() ??
                '',
          ) ??
          0.0,
      monthlyPremium: double.tryParse(
            json['prima_mensual']?.toString() ??
                json['prima']?.toString() ??
                '',
          ) ??
          0.0,
      emissionMileage: int.tryParse(
            json['kilometraje_emision']?.toString() ??
                json['mileage']?.toString() ??
                '',
          ) ??
          0,
      deductibles: deds,
      coverages: covs,
      clientName: json['clientName']?.toString() ?? json['cliente_nombre']?.toString(),
      paymentStatus: json['paymentStatus']?.toString() ?? json['estado_pago']?.toString(),
      lastPaymentDate: json['lastPaymentDate']?.toString() ?? json['ultimo_pago']?.toString(),
    );
  }



  Map<String, dynamic> toJson() => {
    'id': id,
    'numero_poliza': number,
    'cliente_id': clientId,
    'vehiculo_id': vehicleId,
    if (vehicle != null) 'vehiculo': vehicle!.toJson(),
    'fecha_inicio': startDate.toIso8601String().substring(0, 10),
    'fecha_fin': endDate.toIso8601String().substring(0, 10),
    'estado': status,
    'valor_asegurado': insuredValue,
    'prima_mensual': monthlyPremium,
    'kilometraje_emision': emissionMileage,
    'deducibles': deductibles.map((d) => d.toJson()).toList(),
    'coberturas': coverages,
    if (clientName != null) 'clientName': clientName,
    if (paymentStatus != null) 'paymentStatus': paymentStatus,
    if (lastPaymentDate != null) 'lastPaymentDate': lastPaymentDate,
  };
}
