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

  // Formatos ANT Ecuador
  static const int minPlateLength = 6;
  static const int maxPlateLength = 8;
  static const int ecuadorianIdLength = 10;
}
