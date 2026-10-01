import 'dart:convert';
import 'package:sigad/core/models/catalog_model.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/models/deductible_model.dart';
import 'package:sigad/core/models/payment_model.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'test_factories.dart';

/// Single Source of Truth (SSOT) para datos y fixtures de prueba (Object Mother).
///
/// Centraliza todas las identidades, credenciales, respuestas HTTP simuladas y entidades
/// canónicas para erradicar por completo la Cirugía con Escopeta (Shotgun Surgery)
/// y la dispersión de datos mágicos en la suite de pruebas.
class TestFixtures {
  // --- CREDENCIALES Y TOKENS CANÓNICOS ---
  static const String validToken = 'jwt_mock_token_valid';
  static const String refreshToken = 'jwt_refresh_mock_token';
  static const String activationToken = 'mock_activation_access_token';
  static const String activationRefreshToken = 'mock_activation_refresh_token';
  static const String manualOverrideToken = 'token-manual';

  static const String validCedula = '0926687856';
  static const String validOtp = '458921';
  static const String validPassword = 'PasswordSeguro2026*';

  static const String adminEmail = 'admin@sigad.ec';
  static const String adminPassword = 'Admin#SIGAD24';

  static const String clientEmail = 'cliente@seguro.ec';

  // --- CONFIGURACIÓN Y URLs CANÓNICAS ---
  static const String testBaseUrl = 'http://test-server:8000';

  // --- VECTORES DE PRUEBA: CREDENCIALES INVÁLIDAS / MALFORMADAS ---
  static const String invalidCedulaModulo10 = '1234567890';
  static const String shortOtp = '12345';
  static const String invalidOtp = '000000';

  static const String passwordTooShort = 'Corto1!';
  static const String passwordMissingUpper = 'sinmayuscula123!';
  static const String passwordMissingLower = 'SINMINUSCULA123!';
  static const String passwordMissingDigit = 'SinNumerosPassword!';
  static const String passwordMissingSpecial = 'SinSimbolosEspeciales123';
  static const String mismatchedPassword = 'OtraPassword2026*';

  static const String wrongPassword = 'WrongPassword';
  static const String wrongPassword1 = 'WrongPassword1';
  static const String wrongPassword2 = 'WrongPassword2';
  static const String wrongPassword3 = 'WrongPassword3';

  // --- MENSAJES Y ERRORES ESTÁNDAR ---
  static const String invalidCredentialsMessage = 'Las credenciales ingresadas no son válidas.';
  static const String serverErrorMessage = 'Error de conexión con el servidor';
  static const String invalidCredentialsDetail = 'Invalid credentials';
  static const String otpInvalidDetail = 'Código de vinculación inválido o expirado.';
  static const String otpLengthMessage = 'Ingresa los 6 dígitos del código';
  static const String passwordMismatchMessage = 'Las contraseñas no coinciden';
  static const String cedulaRequiredMessage = 'Ingresa tu cédula';
  static const String cedulaInvalidModulo10 = 'Cédula ecuatoriana inválida (Módulo 10)';
  static const String passwordMinLength = 'Debe tener al menos 12 caracteres';
  static const String passwordRequiresUpper = 'Debe incluir al menos una mayúscula';
  static const String passwordRequiresLower = 'Debe incluir al menos una minúscula';
  static const String passwordRequiresNumber = 'Debe incluir al menos un número';
  static const String passwordRequiresSpecial = 'Debe incluir un símbolo especial';

  // --- ENTIDADES CANÓNICAS DE USUARIO ---
  static final UserModel adminUser = TestFactories.createUser(
    id: 'usr-admin-1',
    email: adminEmail,
    name: 'Administrador del Sistema',
    role: 'admin_system',
    accessToken: validToken,
    refreshToken: refreshToken,
    isActive: true,
  );

  static Map<String, dynamic> get adminUserJson => TestFactories.createUserJson(
        id: adminUser.id,
        email: adminUser.email,
        name: adminUser.name,
        role: adminUser.role,
        isActive: adminUser.isActive,
        accessToken: validToken,
        refreshToken: refreshToken,
      );

  static final UserModel clientUser = TestFactories.createUser(
    id: 'client-usr-1',
    email: clientEmail,
    name: 'Juan Perez Cliente',
    role: 'cliente',
    accessToken: activationToken,
    refreshToken: activationRefreshToken,
    isActive: true,
  );

  static Map<String, dynamic> get clientUserJson => TestFactories.createUserJson(
        id: clientUser.id,
        email: clientUser.email,
        name: clientUser.name,
        role: clientUser.role,
        isActive: clientUser.isActive,
        accessToken: activationToken,
        refreshToken: activationRefreshToken,
      );

  // --- RESPUESTAS HTTP CANNED (MOCKS) ---
  static String authSuccessResponseBody({
    UserModel? user,
    String? token,
    String? refresh,
  }) {
    final u = user ?? adminUser;
    return jsonEncode({
      'access_token': token ?? validToken,
      'refresh_token': refresh ?? refreshToken,
      'user': TestFactories.createUserJson(
        id: u.id,
        email: u.email,
        name: u.name,
        role: u.role,
        isActive: u.isActive,
      ),
    });
  }

  static String activationSuccessResponseBody({
    UserModel? user,
    String? token,
    String? refresh,
  }) {
    final u = user ?? clientUser;
    return jsonEncode({
      'access_token': token ?? activationToken,
      'refresh_token': refresh ?? activationRefreshToken,
      'user': TestFactories.createUserJson(
        id: u.id,
        email: u.email,
        name: u.name,
        role: u.role,
        isActive: u.isActive,
      ),
    });
  }

  static String errorDetailBody(String detail) => jsonEncode({'detail': detail});

  // --- VEHÍCULO Y CLIENTE CANÓNICOS ---
  static final VehicleModel standardVehicle = TestFactories.createVehicle(
    id: 'veh-std-100',
    plate: 'PBC-4321',
    brand: 'Chevrolet',
    model: 'D-Max',
    year: 2024,
    color: 'Blanco',
    type: 'Camioneta',
  );

  static Map<String, dynamic> get standardVehicleJson => standardVehicle.toJson();

  static final ClientModel standardClient = TestFactories.createClient(
    id: 'cli-std-100',
    identificacion: validCedula,
    nombres: 'Juan Perez Cliente',
    email: clientEmail,
    telefono: '0991234567',
  );

  static Map<String, dynamic> get standardClientJson => standardClient.toJson();

  // --- PÓLIZAS CANÓNICAS ---
  static final PolicyModel activePolicy = TestFactories.createPolicy(
    id: 'pol-act-100',
    number: 'POL-EC-2026-999',
    clientId: standardClient.id,
    vehicleId: standardVehicle.id,
    vehicle: standardVehicle,
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2027, 1, 1),
    status: 'activa',
    insuredValue: 28000.0,
    monthlyPremium: 85.0,
    emissionMileage: 12000,
    clientName: standardClient.nombres,
    paymentStatus: null,
  );

  static Map<String, dynamic> get activePolicyJson => activePolicy.toJson();

  // --- CUOTAS Y PAGOS CANÓNICOS ---
  static final PaymentModel paidPayment = TestFactories.createPayment(
    id: 'pago-01-paid',
    policyId: activePolicy.id,
    installmentNumber: 1,
    amountUsd: 85.0,
    dueDate: DateTime(2026, 1, 15),
    paymentDate: DateTime(2026, 1, 14),
    status: 'pagado',
    paymentMethod: 'transferencia',
    receiptRef: 'REF-TRX-12345',
  );

  static Map<String, dynamic> get paidPaymentJson => TestFactories.createPaymentJson(
        id: paidPayment.id,
        policyId: paidPayment.policyId,
        installmentNumber: paidPayment.installmentNumber,
        amountUsd: paidPayment.amountUsd,
        dueDate: paidPayment.dueDate,
        paymentDate: paidPayment.paymentDate,
        status: paidPayment.status,
        paymentMethod: paidPayment.paymentMethod,
        receiptRef: paidPayment.receiptRef,
      );

  static final PaymentModel pendingPayment = TestFactories.createPayment(
    id: 'pago-02-pending',
    policyId: activePolicy.id,
    installmentNumber: 2,
    amountUsd: 85.0,
    dueDate: DateTime.now().add(const Duration(days: 10)),
    status: 'pendiente',
  );

  static Map<String, dynamic> get pendingPaymentJson => TestFactories.createPaymentJson(
        id: pendingPayment.id,
        policyId: pendingPayment.policyId,
        installmentNumber: pendingPayment.installmentNumber,
        amountUsd: pendingPayment.amountUsd,
        dueDate: pendingPayment.dueDate,
        status: pendingPayment.status,
      );

  static final PaymentModel overduePayment = TestFactories.createPayment(
    id: 'pago-03-overdue',
    policyId: activePolicy.id,
    installmentNumber: 3,
    amountUsd: 85.0,
    dueDate: DateTime.now().subtract(const Duration(days: 5)),
    status: 'atrasado',
  );

  static Map<String, dynamic> get overduePaymentJson => TestFactories.createPaymentJson(
        id: overduePayment.id,
        policyId: overduePayment.policyId,
        installmentNumber: overduePayment.installmentNumber,
        amountUsd: overduePayment.amountUsd,
        dueDate: overduePayment.dueDate,
        status: overduePayment.status,
      );

  // --- DOCUMENTOS OCR CANÓNICOS ---
  static const String ocrSampleDocumentId = 'd1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
  static const String ocrSampleFilename = 'poliza_contrato_ejemplo.pdf';

  static final Map<String, dynamic> ocrDocumentSample = {
    'id': ocrSampleDocumentId,
    'nombre_archivo': ocrSampleFilename,
    'tipo_mime': 'application/pdf',
    'tamano_bytes': 204800,
    'estado_extraccion': 'requiere_revision_manual',
    'resultado': {
      'metodo': 'tesseract_200dpi',
      'confianza': 78.5,
      'campos_extraidos': {
        'placa': 'PBX-1234',
        'valor_asegurado': '18500.00',
        'prima_mensual': '45.50',
        'numero_poliza': 'POL-OCR-9999',
        'kilometraje': '12500',
      },
      'texto_completo': 'CONTRATO DE SEGURO VEHICULAR PLACA PBX-1234',
    },
  };

  // --- CATÁLOGOS CANÓNICOS ---
  static final WorkshopModel standardWorkshop = TestFactories.createWorkshop(
    id: 'tal-std-01',
    name: 'Taller Central Guayaquil',
    address: 'Av. Juan Tanca Marengo Km 4.5',
    phone: '04-2598700',
    city: 'Guayaquil',
    active: true,
  );
  static Map<String, dynamic> get standardWorkshopJson => standardWorkshop.toJson();

  static final AssistanceModel standardAssistance = TestFactories.createAssistance(
    id: 'ast-std-01',
    title: 'Grúa y Remolque',
    description: 'Traslado de vehículo averiado 24/7.',
    emergencyPhone: '1800-757-348',
    icon: 'local_shipping',
    active: true,
  );
  static Map<String, dynamic> get standardAssistanceJson => standardAssistance.toJson();

  // --- DEDUCIBLES Y COBERTURAS CANÓNICAS ---
  static final DeductibleModel standardDeductible = TestFactories.createDeductible(
    id: 'ded-std-01',
    tipoSiniestro: 'general',
    porcentajeValor: 10.0,
    montoMinimoUsd: 200.0,
  );
  static Map<String, dynamic> get standardDeductibleJson => standardDeductible.toJson();

  static final CoverageModel standardCoverage = TestFactories.createCoverage(
    id: 'cov-std-01',
    nombre: 'Responsabilidad Civil',
    monto: 5000.0,
  );
  static Map<String, dynamic> get standardCoverageJson => standardCoverage.toJson();

  static const List<CoverageModel> standardCoverages = [
    CoverageModel(id: 'cov-std-01', nombre: 'Todo Riesgo', monto: 5000.0),
    CoverageModel(id: 'cov-std-02', nombre: 'Responsabilidad Civil', monto: 3000.0),
  ];
}
