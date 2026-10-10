import 'package:sigad/core/models/deductible_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/core/utils/date_formatter.dart';
import 'package:sigad/core/utils/numeric_parser.dart';

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

  Map<String, dynamic> toCreatePayloadJson() => {
        'nombre': nombre,
        'monto': monto,
      };
}

class PolicyModel {
  final String id;
  final String number;
  final String clientId;
  final String vehicleId;
  final VehicleModel? vehicle;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final double insuredValue;
  final double monthlyPremium;
  final int emissionMileage;
  final List<DeductibleModel> deductibles;
  final List<CoverageModel> coverages;
  final String? clientName;
  final String? paymentStatus;
  final String? lastPaymentDate;
  final String? esquemaId;
  final Map<String, dynamic>? camposAdicionales;

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
    this.esquemaId,
    this.camposAdicionales,
  });

  int get daysUntilExpiration => endDate.difference(DateTime.now()).inDays;
  bool get isExpired =>
      DateTime.now().isAfter(endDate) || status.toLowerCase() == 'vencida';
  bool get isExpiringSoon =>
      !isExpired && daysUntilExpiration <= 30 && daysUntilExpiration >= 0;

  static List<PolicyModel> sortByActivePriority(List<PolicyModel> policies) {
    final copy = List<PolicyModel>.from(policies);
    copy.sort((a, b) => (!b.isExpired ? 1 : 0).compareTo(!a.isExpired ? 1 : 0));
    return copy;
  }

  static int countActivePolicies(List<PolicyModel> policies) {
    return policies.where((p) => !p.isExpired).length;
  }

  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    VehicleModel? veh;
    if (json['vehiculo'] is Map<String, dynamic>) {
      veh = VehicleModel.fromJson(json['vehiculo'] as Map<String, dynamic>);
    }

    final dedsList = json['deducibles'] as List<dynamic>?;
    final deds = dedsList != null
        ? dedsList.map((d) => DeductibleModel.fromJson(d as Map<String, dynamic>)).toList()
        : const <DeductibleModel>[];

    final covsList = json['coberturas'] as List<dynamic>?;
    final covs = covsList != null
        ? covsList.map((c) => CoverageModel.fromJson(c as Map<String, dynamic>)).toList()
        : const <CoverageModel>[];

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
      esquemaId: json['esquema_id'] as String?,
      camposAdicionales: json['campos_adicionales'] != null
          ? Map<String, dynamic>.from(json['campos_adicionales'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toCreatePayloadJson() => {
        'numero_poliza': number,
        'cliente_id': clientId,
        'vehiculo_id': vehicleId,
        'fecha_inicio': DateFormatter.toIsoDate(startDate),
        'fecha_fin': DateFormatter.toIsoDate(endDate),
        'valor_asegurado': insuredValue,
        'prima_mensual': monthlyPremium,
        'kilometraje_emision': emissionMileage,
        if (esquemaId != null) 'esquema_id': esquemaId,
        if (camposAdicionales != null && camposAdicionales!.isNotEmpty)
          'campos_adicionales': camposAdicionales,
        if (deductibles.isNotEmpty)
          'deducibles': deductibles.map((d) => d.toCreatePayloadJson()).toList(),
        if (coverages.isNotEmpty)
          'coberturas': coverages.map((c) => c.toCreatePayloadJson()).toList(),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'numero_poliza': number,
        'cliente_id': clientId,
        'vehiculo_id': vehicleId,
        if (vehicle != null) 'vehiculo': vehicle!.toJson(),
        if (esquemaId != null) 'esquema_id': esquemaId,
        'fecha_inicio': DateFormatter.toIsoDate(startDate),
        'fecha_fin': DateFormatter.toIsoDate(endDate),
        'estado': status,
        'valor_asegurado': insuredValue,
        'prima_mensual': monthlyPremium,
        'kilometraje_emision': emissionMileage,
        if (camposAdicionales != null && camposAdicionales!.isNotEmpty)
          'campos_adicionales': camposAdicionales,
        'deducibles': deductibles.map((d) => d.toJson()).toList(),
        'coberturas': coverages.map((c) => c.toJson()).toList(),
        if (clientName != null) 'cliente_nombre': clientName,
        if (paymentStatus != null) 'estado_pago': paymentStatus,
        if (lastPaymentDate != null) 'ultimo_pago': lastPaymentDate,
      };
}

class CreatePolicyRequest {
  final String number;
  final String clientId;
  final String? vehicleId;
  final VehicleModel? vehicle;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final double? insuredValue;
  final double? monthlyPremium;
  final int? emissionMileage;
  final List<String> coverages;
  final List<DeductibleModel> deductibles;
  final String? esquemaId;
  final Map<String, dynamic>? camposAdicionales;

  const CreatePolicyRequest({
    required this.number,
    required this.clientId,
    this.vehicleId,
    this.vehicle,
    required this.startDate,
    required this.endDate,
    this.status = 'activa',
    this.insuredValue,
    this.monthlyPremium,
    this.emissionMileage,
    this.coverages = const [],
    this.deductibles = const [],
    this.esquemaId,
    this.camposAdicionales,
  });

  Map<String, dynamic> toCreatePayloadJson({String? resolvedVehicleId}) {
    final vId = resolvedVehicleId ?? vehicleId;
    if (vId == null || vId.isEmpty) {
      throw StateError('FAIL-FAST: vehiculo_id es requerido para emitir una póliza.');
    }
    if (insuredValue == null || monthlyPremium == null || emissionMileage == null) {
      throw StateError('FAIL-FAST: No se puede serializar CreatePolicyRequest con datos financieros o de kilometraje ausentes.');
    }
    return {
      'numero_poliza': number,
      'cliente_id': clientId,
      'vehiculo_id': vId,
      'fecha_inicio': DateFormatter.toIsoDate(startDate),
      'fecha_fin': DateFormatter.toIsoDate(endDate),
      'valor_asegurado': insuredValue!,
      'prima_mensual': monthlyPremium!,
      'kilometraje_emision': emissionMileage!,
      if (esquemaId != null) 'esquema_id': esquemaId,
      if (camposAdicionales != null && camposAdicionales!.isNotEmpty)
        'campos_adicionales': camposAdicionales,
      if (deductibles.isNotEmpty)
        'deducibles': deductibles.map((d) => d.toCreatePayloadJson()).toList(),
      if (coverages.isNotEmpty)
        'coberturas': coverages
            .map((c) => {'nombre': c, 'monto': insuredValue!})
            .toList(),
    };
  }
}
