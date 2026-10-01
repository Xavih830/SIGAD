// ignore_for_file: use_null_aware_elements
import 'package:sigad/core/models/catalog_model.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/models/deductible_model.dart';
import 'package:sigad/core/models/payment_model.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';

/// Test Data Builder y Object Mother centralizado para pruebas unitarias y de widgets.
///
/// Previene la fragilidad de pruebas ("Shotgun Surgery") al desacoplar las definiciones
/// de esquemas de cada prueba individual.
class TestFactories {
  static int _sequence = 1;

  static int get nextSequence => _sequence++;

  // --- VEHICLE FACTORIES ---

  static VehicleModel createVehicle({
    String? id,
    String? plate,
    String? brand,
    String? model,
    int? year,
    String? color,
    String? type,
    double? tonnage,
    String? clientId,
  }) {
    final seq = nextSequence;
    return VehicleModel(
      id: id ?? 'veh-$seq',
      plate: plate ?? 'PBA-${1000 + seq}',
      brand: brand ?? 'Toyota',
      model: model ?? 'Corolla Cross',
      year: year ?? 2023,
      color: color ?? 'Blanco',
      type: type ?? 'SUV',
      tonnage: tonnage,
      clientId: clientId ?? 'cli-$seq',
    );
  }

  static Map<String, dynamic> createVehicleJson({
    String? id,
    String? plate,
    String? brand,
    String? model,
    int? year,
    String? color,
    String? type,
    double? tonnage,
    String? clientId,
  }) {
    return createVehicle(
      id: id,
      plate: plate,
      brand: brand,
      model: model,
      year: year,
      color: color,
      type: type,
      tonnage: tonnage,
      clientId: clientId,
    ).toJson();
  }

  // --- DEDUCTIBLE FACTORIES ---

  static DeductibleModel createDeductible({
    String? id,
    String? tipoSiniestro,
    double? porcentajeValor,
    double? montoMinimoUsd,
  }) {
    final seq = nextSequence;
    return DeductibleModel(
      id: id ?? 'ded-$seq',
      tipoSiniestro: tipoSiniestro ?? 'general',
      porcentajeValor: porcentajeValor ?? 10.0,
      montoMinimoUsd: montoMinimoUsd ?? 200.0,
    );
  }

  static Map<String, dynamic> createDeductibleJson({
    String? id,
    String? tipoSiniestro,
    double? porcentajeValor,
    double? montoMinimoUsd,
  }) {
    return createDeductible(
      id: id,
      tipoSiniestro: tipoSiniestro,
      porcentajeValor: porcentajeValor,
      montoMinimoUsd: montoMinimoUsd,
    ).toJson();
  }

  // --- COVERAGE FACTORIES ---

  static CoverageModel createCoverage({
    String? id,
    String? nombre,
    double? monto,
  }) {
    final seq = nextSequence;
    return CoverageModel(
      id: id ?? 'cov-$seq',
      nombre: nombre ?? 'Responsabilidad Civil',
      monto: monto ?? 5000.0,
    );
  }

  static Map<String, dynamic> createCoverageJson({
    String? id,
    String? nombre,
    double? monto,
  }) {
    return createCoverage(
      id: id,
      nombre: nombre,
      monto: monto,
    ).toJson();
  }

  // --- POLICY FACTORIES ---

  static PolicyModel createPolicy({
    String? id,
    String? number,
    String? clientId,
    String? vehicleId,
    VehicleModel? vehicle,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    double? insuredValue,
    double? monthlyPremium,
    int? emissionMileage,
    List<DeductibleModel>? deductibles,
    List<CoverageModel>? coverages,
    String? clientName,
    String? paymentStatus,
    String? lastPaymentDate,
  }) {
    final seq = nextSequence;
    final start = startDate ?? DateTime(2026, 1, 1);
    final end = endDate ?? DateTime(2027, 1, 1);

    return PolicyModel(
      id: id ?? 'pol-$seq',
      number: number ?? 'POL-2026-00$seq',
      clientId: clientId ?? 'cli-$seq',
      vehicleId: vehicleId ?? 'veh-$seq',
      vehicle: vehicle ?? createVehicle(id: vehicleId ?? 'veh-$seq'),
      startDate: start,
      endDate: end,
      status: status ?? 'activa',
      insuredValue: insuredValue ?? 19500.00,
      monthlyPremium: monthlyPremium ?? 65.00,
      emissionMileage: emissionMileage ?? 15000,
      deductibles: deductibles ?? [createDeductible()],
      coverages: coverages ??
          const [
            CoverageModel(id: 'cov-1', nombre: 'Responsabilidad Civil', monto: 50000),
            CoverageModel(id: 'cov-2', nombre: 'Pérdida Total', monto: 19500),
          ],
      clientName: clientName ?? 'Cliente Prueba',
      paymentStatus: paymentStatus,
      lastPaymentDate: lastPaymentDate,
    );
  }

  static Map<String, dynamic> createPolicyJson({
    String? id,
    String? number,
    String? clientId,
    String? vehicleId,
    VehicleModel? vehicle,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    double? insuredValue,
    double? monthlyPremium,
    int? emissionMileage,
    List<DeductibleModel>? deductibles,
    List<CoverageModel>? coverages,
    String? clientName,
    String? paymentStatus,
    String? lastPaymentDate,
  }) {
    return createPolicy(
      id: id,
      number: number,
      clientId: clientId,
      vehicleId: vehicleId,
      vehicle: vehicle,
      startDate: startDate,
      endDate: endDate,
      status: status,
      insuredValue: insuredValue,
      monthlyPremium: monthlyPremium,
      emissionMileage: emissionMileage,
      deductibles: deductibles,
      coverages: coverages,
      clientName: clientName,
      paymentStatus: paymentStatus,
      lastPaymentDate: lastPaymentDate,
    ).toJson();
  }

  // --- PAYMENT FACTORIES ---

  static PaymentModel createPayment({
    String? id,
    String? policyId,
    int? installmentNumber,
    double? amountUsd,
    DateTime? dueDate,
    DateTime? paymentDate,
    String? status,
    String? paymentMethod,
    String? receiptRef,
  }) {
    final seq = nextSequence;
    return PaymentModel(
      id: id ?? 'pago-$seq',
      policyId: policyId ?? 'pol-100',
      installmentNumber: installmentNumber ?? 1,
      amountUsd: amountUsd ?? 85.00,
      dueDate: dueDate ?? DateTime(2026, 1, 15),
      paymentDate: paymentDate,
      status: status ?? 'pendiente',
      paymentMethod: paymentMethod,
      receiptRef: receiptRef,
    );
  }

  static Map<String, dynamic> createPaymentJson({
    String? id,
    String? policyId,
    int? installmentNumber,
    double? amountUsd,
    DateTime? dueDate,
    DateTime? paymentDate,
    String? status,
    String? paymentMethod,
    String? receiptRef,
  }) {
    final d = dueDate ?? DateTime(2026, 1, 15);
    final dueStr = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String? payStr;
    if (paymentDate != null) {
      payStr = '${paymentDate.year.toString().padLeft(4, '0')}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}';
    }

    final seq = nextSequence;
    return {
      'id': id ?? 'pago-$seq',
      'poliza_id': policyId ?? 'pol-100',
      'numero_cuota': installmentNumber ?? 1,
      'monto_usd': amountUsd ?? 85.00,
      'fecha_vencimiento': dueStr,
      if (payStr != null) 'fecha_pago': payStr,
      'estado': status ?? 'pendiente',
      if (paymentMethod != null) 'metodo_pago': paymentMethod,
      if (receiptRef != null) 'comprobante_ref': receiptRef,
    };
  }

  // --- USER FACTORIES ---

  static UserModel createUser({
    String? id,
    String? email,
    String? name,
    String? role,
    String? accessToken,
    String? refreshToken,
    bool? isActive,
  }) {
    final seq = nextSequence;
    return UserModel(
      id: id ?? 'usr-$seq',
      email: email ?? 'usuario$seq@sigad.ec',
      name: name ?? 'Usuario Test $seq',
      role: role ?? 'cliente',
      accessToken: accessToken,
      refreshToken: refreshToken,
      isActive: isActive ?? true,
    );
  }

  static Map<String, dynamic> createUserJson({
    String? id,
    String? email,
    String? name,
    String? role,
    String? accessToken,
    String? refreshToken,
    bool? isActive,
  }) {
    final seq = nextSequence;
    return {
      'id': id ?? 'usr-$seq',
      'email': email ?? 'usuario$seq@sigad.ec',
      'nombre': name ?? 'Usuario Test $seq',
      'rol': role ?? 'cliente',
      'activo': isActive ?? true,
      if (accessToken != null) 'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
    };
  }

  // --- CLIENT FACTORIES ---

  static ClientModel createClient({
    String? id,
    String? identificacion,
    String? nombres,
    String? email,
    String? telefono,
    String? usuarioId,
    String? codigoVinculacion,
    DateTime? createdAt,
  }) {
    final seq = nextSequence;
    return ClientModel(
      id: id ?? 'cli-$seq',
      identificacion: identificacion ?? '0926687856',
      nombres: nombres ?? 'Cliente Test $seq',
      email: email ?? 'cliente$seq@sigad.ec',
      telefono: telefono ?? '0991234567',
      usuarioId: usuarioId,
      codigoVinculacion: codigoVinculacion,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> createClientJson({
    String? id,
    String? identificacion,
    String? nombres,
    String? email,
    String? telefono,
    String? usuarioId,
    String? codigoVinculacion,
    DateTime? createdAt,
  }) {
    return createClient(
      id: id,
      identificacion: identificacion,
      nombres: nombres,
      email: email,
      telefono: telefono,
      usuarioId: usuarioId,
      codigoVinculacion: codigoVinculacion,
      createdAt: createdAt,
    ).toJson();
  }

  // --- WORKSHOP & ASSISTANCE FACTORIES ---

  static WorkshopModel createWorkshop({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? city,
    bool? active,
  }) {
    final seq = nextSequence;
    return WorkshopModel(
      id: id ?? 'tal-$seq',
      name: name ?? 'Taller Central $seq',
      address: address ?? 'Av. Principal Km $seq',
      phone: phone ?? '04-2598700',
      city: city ?? 'Guayaquil',
      active: active ?? true,
    );
  }

  static Map<String, dynamic> createWorkshopJson({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? city,
    bool? active,
  }) {
    return createWorkshop(
      id: id,
      name: name,
      address: address,
      phone: phone,
      city: city,
      active: active,
    ).toJson();
  }

  static AssistanceModel createAssistance({
    String? id,
    String? title,
    String? description,
    String? emergencyPhone,
    String? icon,
    bool? active,
  }) {
    final seq = nextSequence;
    return AssistanceModel(
      id: id ?? 'ast-$seq',
      title: title ?? 'Asistencia Vial $seq',
      description: description ?? 'Servicio de grúa 24/7',
      emergencyPhone: emergencyPhone ?? '1800-757-348',
      icon: icon ?? 'local_shipping',
      active: active ?? true,
    );
  }

  static Map<String, dynamic> createAssistanceJson({
    String? id,
    String? title,
    String? description,
    String? emergencyPhone,
    String? icon,
    bool? active,
  }) {
    return createAssistance(
      id: id,
      title: title,
      description: description,
      emergencyPhone: emergencyPhone,
      icon: icon,
      active: active,
    ).toJson();
  }
}
