abstract class ApiEndpoints {
  static const String authLogin = '/api/v1/auth/login';
  static const String authVinculacion = '/api/v1/auth/vinculacion';

  static const String polizasBase = '/api/v1/polizas';
  static String polizas({int skip = 0, int limit = 50}) =>
      '/api/v1/polizas?skip=$skip&limit=$limit';
  static String poliza(String id) => '/api/v1/polizas/$id';
  static String polizaEstado(String id) => '/api/v1/polizas/$id/estado';
  static String polizaDeducibles(String id) => '/api/v1/polizas/$id/deducibles';
  static String polizaPagos(String policyId) => '/api/v1/polizas/$policyId/pagos';
  static String polizaRegistrarPago(String policyId, String paymentId) =>
      '/api/v1/polizas/$policyId/pagos/$paymentId/registrar';

  static const String clientes = '/api/v1/clientes';
  static String cliente(String clientId) => '/api/v1/clientes/$clientId';
  static String clienteOtp(String clientId) => '/api/v1/clientes/$clientId/otp';

  static const String vehiculos = '/api/v1/vehiculos';
  static String vehiculo(String vehicleId) => '/api/v1/vehiculos/$vehicleId';

  static const String documentos = '/api/v1/documentos';
  static String documento(String documentId) => '/api/v1/documentos/$documentId';
  static String documentoRevision(String documentId) =>
      '/api/v1/documentos/$documentId/revision';
  static String documentoDescarga(String documentId) =>
      '/api/v1/documentos/$documentId/descargar';

  static const String esquemas = '/api/v1/esquemas';
  static String esquema(String id) => '/api/v1/esquemas/$id';
  static String esquemaActivar(String id) => '/api/v1/esquemas/$id/activar';
  static String esquemaProbar(String id) => '/api/v1/esquemas/$id/probar';

  static const String esquemasPoliza = '/api/v1/esquemas-poliza';
  static String esquemaPoliza(String id) => '$esquemasPoliza/$id';
  static String esquemaPolizaActivar(String id) => '$esquemasPoliza/$id/activar';

  static const String talleres = '/api/v1/talleres';
  static String taller(String id) => '/api/v1/talleres/$id';
  static const String asistencias = '/api/v1/asistencias';
  static String asistencia(String id) => '/api/v1/asistencias/$id';

  static const String healthLive = '/health/live';
  static const String healthReady = '/health/ready';
}
