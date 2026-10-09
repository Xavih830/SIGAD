// ignore_for_file: use_null_aware_elements
import 'package:sigad/core/models/catalog_model.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/models/deductible_model.dart';
import 'package:sigad/core/models/document_model.dart';
import 'package:sigad/core/models/extraction_schema_model.dart';
import 'package:sigad/core/models/payment_model.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';

class TestFactories {
  static int _sequence = 1;

  static int get nextSequence => _sequence++;

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
    bool asDecimalStrings = false,
  }) {
    final map = createPolicy(
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

    if (asDecimalStrings) {
      map['valor_asegurado'] = (map['valor_asegurado'] as num).toStringAsFixed(2);
      map['prima_mensual'] = (map['prima_mensual'] as num).toStringAsFixed(2);
      if (map['deducibles'] is List) {
        map['deducibles'] = (map['deducibles'] as List).map((d) {
          final dMap = Map<String, dynamic>.from(d as Map);
          if (dMap['porcentaje_valor'] is num) {
            dMap['porcentaje_valor'] = (dMap['porcentaje_valor'] as num).toStringAsFixed(2);
          }
          if (dMap['monto_minimo_usd'] is num) {
            dMap['monto_minimo_usd'] = (dMap['monto_minimo_usd'] as num).toStringAsFixed(2);
          }
          return dMap;
        }).toList();
      }
      if (map['coberturas'] is List) {
        map['coberturas'] = (map['coberturas'] as List).map((c) {
          final cMap = Map<String, dynamic>.from(c as Map);
          if (cMap['monto'] is num) {
            cMap['monto'] = (cMap['monto'] as num).toStringAsFixed(2);
          }
          return cMap;
        }).toList();
      }
    }
    return map;
  }

  static CreatePolicyRequest createPolicyRequest({
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
    List<String>? coverages,
    List<DeductibleModel>? deductibles,
  }) {
    final seq = nextSequence;
    return CreatePolicyRequest(
      number: number ?? 'POL-2026-REQ-$seq',
      clientId: clientId ?? 'cli-$seq',
      vehicleId: vehicleId,
      vehicle: vehicle,
      startDate: startDate ?? DateTime(2026, 1, 1),
      endDate: endDate ?? DateTime(2027, 1, 1),
      status: status ?? 'activa',
      insuredValue: insuredValue ?? 19500.00,
      monthlyPremium: monthlyPremium ?? 65.00,
      emissionMileage: emissionMileage ?? 15000,
      coverages: coverages ?? const ['Responsabilidad Civil'],
      deductibles: deductibles ?? [createDeductible()],
    );
  }

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
    bool asDecimalStrings = false,
  }) {
    final d = dueDate ?? DateTime(2026, 1, 15);
    final dueStr = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String? payStr;
    if (paymentDate != null) {
      payStr = '${paymentDate.year.toString().padLeft(4, '0')}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}';
    }

    final seq = nextSequence;
    final val = amountUsd ?? 85.00;
    return {
      'id': id ?? 'pago-$seq',
      'poliza_id': policyId ?? 'pol-100',
      'numero_cuota': installmentNumber ?? 1,
      'monto_usd': asDecimalStrings ? val.toStringAsFixed(2) : val,
      'fecha_vencimiento': dueStr,
      if (payStr != null) 'fecha_pago': payStr,
      'estado': status ?? 'pendiente',
      if (paymentMethod != null) 'metodo_pago': paymentMethod,
      if (receiptRef != null) 'comprobante_ref': receiptRef,
    };
  }

  static UserModel createUser({
    String? id,
    String? email,
    String? name,
    dynamic role,
    String? accessToken,
    String? refreshToken,
    bool? isActive,
  }) {
    final seq = nextSequence;
    final UserRole parsedRole;
    if (role is UserRole) {
      parsedRole = role;
    } else if (role is String) {
      parsedRole = UserRole.fromValue(role);
    } else {
      parsedRole = UserRole.cliente;
    }
    return UserModel(
      id: id ?? 'usr-$seq',
      email: email ?? 'usuario$seq@sigad.ec',
      name: name ?? 'Usuario Test $seq',
      role: parsedRole,
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

  static DocumentModel createDocument({
    String? id,
    String? polizaId,
    String? nombreArchivo,
    String? tipoMime,
    int? tamanoBytes,
    String? estadoExtraccion,
    bool? hasResultado,
    DateTime? createdAt,
    Map<String, dynamic>? camposExtraidos,
    String? metodo,
    double? confianza,
    String? textoCompleto,
  }) {
    final seq = nextSequence;
    return DocumentModel(
      id: id ?? 'doc-$seq',
      polizaId: polizaId,
      nombreArchivo: nombreArchivo ?? 'documento_$seq.pdf',
      tipoMime: tipoMime ?? 'application/pdf',
      tamanoBytes: tamanoBytes ?? 102400,
      estadoExtraccion: estadoExtraccion ?? 'completado',
      hasResultado: hasResultado ?? true,
      createdAt: createdAt ?? DateTime.parse('2026-03-15T10:00:00Z'),
      camposExtraidos: camposExtraidos ?? {'numero_poliza': 'POL-$seq'},
      metodo: metodo ?? 'tesseract_200dpi',
      confianza: confianza ?? 95.0,
      textoCompleto: textoCompleto ?? 'Texto del documento $seq',
    );
  }

  static Map<String, dynamic> createDocumentJson({
    String? id,
    String? polizaId,
    String? nombreArchivo,
    String? tipoMime,
    int? tamanoBytes,
    String? estadoExtraccion,
    DateTime? createdAt,
    Map<String, dynamic>? camposExtraidos,
    String? metodo,
    double? confianza,
    String? textoCompleto,
  }) {
    final seq = nextSequence;
    final created = createdAt ?? DateTime.parse('2026-03-15T10:00:00Z');
    return {
      'id': id ?? 'doc-$seq',
      if (polizaId != null) 'poliza_id': polizaId,
      'nombre_archivo': nombreArchivo ?? 'documento_$seq.pdf',
      'tipo_mime': tipoMime ?? 'application/pdf',
      'tamano_bytes': tamanoBytes ?? 102400,
      'estado_extraccion': estadoExtraccion ?? 'completado',
      'created_at': created.toIso8601String(),
      'resultado': {
        'metodo': metodo ?? 'tesseract_200dpi',
        'confianza': confianza ?? 95.0,
        'texto_completo': textoCompleto ?? 'Texto del documento $seq',
        'campos_extraidos': camposExtraidos ?? {'numero_poliza': 'POL-$seq'},
      },
    };
  }

  static ExtractionFieldModel createExtractionField({
    String? nombre,
    String? regex,
    String? tipo,
    int? grupoCaptura,
    String? formatoFecha,
    bool? esObligatorio,
    int? orden,
  }) {
    final seq = nextSequence;
    return ExtractionFieldModel(
      nombre: nombre ?? 'campo_$seq',
      regex: regex ?? r'([A-Z0-9]+)',
      tipo: tipo ?? 'texto',
      grupoCaptura: grupoCaptura ?? 1,
      formatoFecha: formatoFecha,
      esObligatorio: esObligatorio ?? false,
      orden: orden ?? seq,
    );
  }

  static Map<String, dynamic> createExtractionFieldJson({
    String? nombre,
    String? regex,
    String? tipo,
    int? grupoCaptura,
    String? formatoFecha,
    bool? esObligatorio,
    int? orden,
  }) {
    return createExtractionField(
      nombre: nombre,
      regex: regex,
      tipo: tipo,
      grupoCaptura: grupoCaptura,
      formatoFecha: formatoFecha,
      esObligatorio: esObligatorio,
      orden: orden,
    ).toJson();
  }

  static ExtractionSchemaListItemModel createExtractionSchemaListItem({
    String? id,
    String? codigo,
    String? nombre,
    int? version,
    bool? esActivo,
    DateTime? createdAt,
  }) {
    final seq = nextSequence;
    return ExtractionSchemaListItemModel(
      id: id ?? 'sch-$seq',
      codigo: codigo ?? 'ESQUEMA_$seq',
      nombre: nombre ?? 'Esquema de Prueba $seq',
      version: version ?? 1,
      esActivo: esActivo ?? true,
      createdAt: createdAt ?? DateTime.parse('2026-01-01T10:00:00Z'),
    );
  }

  static Map<String, dynamic> createExtractionSchemaListItemJson({
    String? id,
    String? codigo,
    String? nombre,
    int? version,
    bool? esActivo,
    DateTime? createdAt,
  }) {
    return createExtractionSchemaListItem(
      id: id,
      codigo: codigo,
      nombre: nombre,
      version: version,
      esActivo: esActivo,
      createdAt: createdAt,
    ).toJson();
  }

  static ExtractionSchemaModel createExtractionSchema({
    String? id,
    String? codigo,
    String? nombre,
    String? descripcion,
    int? version,
    bool? esActivo,
    String? creadoPor,
    DateTime? createdAt,
    List<ExtractionFieldModel>? campos,
  }) {
    final seq = nextSequence;
    return ExtractionSchemaModel(
      id: id ?? 'sch-$seq',
      codigo: codigo ?? 'ESQUEMA_$seq',
      nombre: nombre ?? 'Esquema de Prueba $seq',
      descripcion: descripcion ?? 'Descripción del esquema $seq',
      version: version ?? 1,
      esActivo: esActivo ?? true,
      creadoPor: creadoPor ?? 'usr-admin-1',
      createdAt: createdAt ?? DateTime.parse('2026-01-01T10:00:00Z'),
      campos: campos ?? [createExtractionField(nombre: 'numero_poliza', regex: r'POL-(\d+)')],
    );
  }

  static Map<String, dynamic> createExtractionSchemaJson({
    String? id,
    String? codigo,
    String? nombre,
    String? descripcion,
    int? version,
    bool? esActivo,
    String? creadoPor,
    DateTime? createdAt,
    List<ExtractionFieldModel>? campos,
  }) {
    return createExtractionSchema(
      id: id,
      codigo: codigo,
      nombre: nombre,
      descripcion: descripcion,
      version: version,
      esActivo: esActivo,
      creadoPor: creadoPor,
      createdAt: createdAt,
      campos: campos,
    ).toJson();
  }

  static TestSchemaResultModel createTestSchemaResult({
    String? metodo,
    double? confianza,
    Map<String, dynamic>? camposExtraidos,
    String? textoCompleto,
  }) {
    return TestSchemaResultModel(
      metodo: metodo ?? 'tesseract_200dpi',
      confianza: confianza ?? 92.5,
      camposExtraidos: camposExtraidos ?? {'numero_poliza': 'POL-12345'},
      textoCompleto: textoCompleto ?? 'TEXTO OCR RECONOCIDO POL-12345',
    );
  }

  static Map<String, dynamic> createTestSchemaResultJson({
    String? metodo,
    double? confianza,
    Map<String, dynamic>? camposExtraidos,
    String? textoCompleto,
  }) {
    return createTestSchemaResult(
      metodo: metodo,
      confianza: confianza,
      camposExtraidos: camposExtraidos,
      textoCompleto: textoCompleto,
    ).toJson();
  }
}
