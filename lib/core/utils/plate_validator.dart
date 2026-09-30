/// Validator for Ecuadorian ANT vehicle license plates (Section 11.2).
///
/// Accepted formats:
/// - Particular / Public: 3 Letters + 4 Digits (e.g. PBA-1234, PTA-1234)
/// - Moto: 2 Letters + 4 Digits (e.g. AB-1234)
/// - Moto actual ANT: 2 Letters + 3 Digits + 1 Letter (e.g. AB-123C)
///
/// Rejected formats:
/// - Old 3L+3D (e.g. XYZ-123)
/// - Inverted (e.g. 1234-ABC)
/// - Special chars / spaces (e.g. AB C-123)
class PlateValidator {
  static final RegExp _plateRegex = RegExp(
    r'^(?:[A-Z]{3}-\d{4}|[A-Z]{2}-\d{4}|[A-Z]{2}-\d{3}[A-Z])$',
  );

  /// Returns true if [plate] complies with official ANT formats.
  static bool isValid(String plate) {
    final clean = plate.trim();
    if (clean.isEmpty) return false;
    return _plateRegex.hasMatch(clean);
  }

  /// Normalizes plate to uppercase with trimmed spaces.
  static String normalize(String plate) {
    return plate.trim().toUpperCase();
  }
}
