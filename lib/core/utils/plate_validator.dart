class PlateValidator {
  static final RegExp _plateRegex = RegExp(
    r'^(?:[A-Z]{3}-\d{4}|[A-Z]{2}-\d{4}|[A-Z]{2}-\d{3}[A-Z])$',
  );

  static bool isValid(String plate) {
    final clean = plate.trim();
    if (clean.isEmpty) return false;
    return _plateRegex.hasMatch(clean);
  }

  static String normalize(String plate) {
    return plate.trim().toUpperCase();
  }
}
