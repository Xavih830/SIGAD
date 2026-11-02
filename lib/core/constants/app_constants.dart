abstract class AppConstants {
  static const int otpLength = 6;
  static const int maxOtpAttempts = 3;
  static const int minPasswordLength = 12;

  static const int maxDocumentSizeBytes = 15 * 1024 * 1024;
  static const int maxPdfPages = 10;
  static const int maxImageDimensionPx = 4096;
  static const int maxImagePixels = 16000000;
  static const List<String> permittedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'tiff'];

  static const Duration apiDefaultTimeout = Duration(seconds: 15);
  static const Duration apiUploadTimeout = Duration(seconds: 30);
  static const Duration catalogCacheTtl = Duration(minutes: 5);

  static const int defaultPageLimit = 50;
  static const int maxPageLimit = 100;
  static const int defaultPageSkip = 0;

  static const int policyExpirationAlertDays = 30;
  static const int maxPolicyYears = 5;
  static const int defaultPolicyDurationDays = 365;

  static const int minPolicyInstallments = 1;
  static const int maxAnnualPolicyInstallments = 12;
  static const int monthlyInstallmentPeriodDays = 30;

  static const int minPlateLength = 6;
  static const int maxPlateLength = 8;
  static const int ecuadorianIdLength = 10;
}
