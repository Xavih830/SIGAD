/// Rutas canónicas de los endpoints del backend FastAPI de SIGAD.
/// Erradica el anti-patrón de 'magic strings' y dispersión de URLs en la capa de red.
abstract class ApiEndpoints {
  // Autenticación
  static const String authLogin = '/api/v1/auth/login';
  static const String authVinculacion = '/api/v1/auth/vinculacion';
  static const String authMe = '/api/v1/auth/me';

  // Pólizas
  static const String polizasBase = '/api/v1/polizas';
  static String polizas({int skip = 0, int limit = 50}) =>
      '/api/v1/polizas?skip=$skip&limit=$limit';
  static String poliza(String id) => '/api/v1/polizas/$id';
  static String polizaEstado(String id) => '/api/v1/polizas/$id/estado';
  static String polizaDeducibles(String id) => '/api/v1/polizas/$id/deducibles';
  static String polizaPagos(String policyId) => '/api/v1/polizas/$policyId/pagos';
  static String polizaRegistrarPago(String policyId, String paymentId) =>
      '/api/v1/polizas/$policyId/pagos/$paymentId/registrar';

  // Clientes
  static const String clientes = '/api/v1/clientes';
  static String clienteOtp(String clientId) => '/api/v1/clientes/$clientId/otp';

  // Vehículos
  static const String vehiculos = '/api/v1/vehiculos';

  // Documentos y OCR
  static const String documentos = '/api/v1/documentos';
  static String documento(String documentId) => '/api/v1/documentos/$documentId';
  static String documentoRevision(String documentId) =>
      '/api/v1/documentos/$documentId/revision';
  static String documentoDescarga(String documentId) =>
      '/api/v1/documentos/$documentId/descargar';

  // Catálogos
  static const String talleres = '/api/v1/talleres';
  static const String asistencias = '/api/v1/asistencias';

  // Monitoreo y Salud
  static const String healthLive = '/health/live';
  static const String healthReady = '/health/ready';
}
