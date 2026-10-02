/// Constantes globales de validación, límites y negocio para SIGAD.
abstract class AppConstants {
  // Autenticación y Seguridad
  static const int otpLength = 6;
  static const int maxOtpAttempts = 3;
  static const int minPasswordLength = 12;

  // Almacenamiento y Archivos
  static const int maxDocumentSizeBytes = 15 * 1024 * 1024; // 15 MB
  static const int maxPdfPages = 10;
  static const List<String> permittedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'tiff'];

  // Pólizas y Vigencias
  static const int policyExpirationAlertDays = 30;
  static const int maxPolicyYears = 5;
  static const int defaultPolicyDurationDays = 365;

  // Valores por defecto de precarga OCR (usados cuando el texto extraído no es parseable)
  static const double ocrDefaultInsuredValue = 15000.0;
  static const double ocrDefaultMonthlyPremium = 35.0;
  static const int ocrDefaultEmissionMileage = 5000;

  // Cronograma de Pagos y Cuotas (HU-20)
  static const int minPolicyInstallments = 1;
  static const int maxAnnualPolicyInstallments = 12;
  static const int monthlyInstallmentPeriodDays = 30;

  // Formatos ANT Ecuador
  static const int minPlateLength = 6;
  static const int maxPlateLength = 8;
  static const int ecuadorianIdLength = 10;
}

