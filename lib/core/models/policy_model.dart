import 'package:sigad/core/models/deductible_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/core/utils/numeric_parser.dart';

/// Modelo canónico para Coberturas en SIGAD.
///
/// Contrato estricto OpenAPI — claves: id, nombre, monto.
class CoverageModel {
  final String id;
  final String nombre;
  final double monto;

  const CoverageModel({
    required this.id,
    required this.nombre,
    required this.monto,
  });

  factory CoverageModel.fromJson(Map<String, dynamic> json) {
    return CoverageModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      monto: parseRequiredDouble(json['monto']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'monto': monto,
      };
}

/// Modelo canónico para Pólizas de Seguro en SIGAD.
///
/// Contrato estricto OpenAPI — sin shims bilingüe ni fallbacks silenciosos.
/// Falla-Rápido: lanza TypeError si el backend omite campos requeridos.
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
  final List<CoverageModel> coverages;
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
  bool get isExpired =>
      DateTime.now().isAfter(endDate) || status.toLowerCase() == 'vencida';
  bool get isExpiringSoon =>
      !isExpired && daysUntilExpiration <= 30 && daysUntilExpiration >= 0;

  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    VehicleModel? veh;
    if (json['vehiculo'] is Map<String, dynamic>) {
      veh = VehicleModel.fromJson(json['vehiculo'] as Map<String, dynamic>);
    }

    final dedsList = json['deducibles'] as List<dynamic>? ?? [];
    final deds = dedsList
        .whereType<Map<String, dynamic>>()
        .map((d) => DeductibleModel.fromJson(d))
        .toList();

    final covsList = json['coberturas'] as List<dynamic>? ?? [];
    final covs = covsList
        .whereType<Map<String, dynamic>>()
        .map((c) => CoverageModel.fromJson(c))
        .toList();

    return PolicyModel(
      id: json['id'] as String,
      number: json['numero_poliza'] as String,
      clientId: json['cliente_id'] as String,
      vehicleId: json['vehiculo_id'] as String,
      vehicle: veh,
      startDate: DateTime.parse(json['fecha_inicio'] as String),
      endDate: DateTime.parse(json['fecha_fin'] as String),
      status: json['estado'] as String,
      insuredValue: parseRequiredDouble(json['valor_asegurado']),
      monthlyPremium: parseRequiredDouble(json['prima_mensual']),
      emissionMileage: json['kilometraje_emision'] as int,
      deductibles: deds,
      coverages: covs,
      clientName: json['cliente_nombre'] as String?,
      paymentStatus: json['estado_pago'] as String?,
      lastPaymentDate: json['ultimo_pago'] as String?,
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
        'coberturas': coverages.map((c) => c.toJson()).toList(),
        if (clientName != null) 'cliente_nombre': clientName,
        if (paymentStatus != null) 'estado_pago': paymentStatus,
        if (lastPaymentDate != null) 'ultimo_pago': lastPaymentDate,
      };
}
