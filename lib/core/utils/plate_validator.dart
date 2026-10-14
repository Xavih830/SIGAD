enum PlateType {
  particular('Particular'),
  moto('Moto'),
  servicioPublico('Servicio Público'),
  gubernamental('Gubernamental');

  final String label;
  const PlateType(this.label);
}

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

  static PlateType? classify(String plate) {
    final clean = plate.trim();
    if (!isValid(clean)) return null;
    final parts = clean.split('-');
    final letters = parts[0];
    if (letters.length == 2) {
      return PlateType.moto;
    }
    if (letters.length == 3) {
      final secondLetter = letters[1];
      if (const ['A', 'U', 'Z'].contains(secondLetter)) {
        return PlateType.servicioPublico;
      }
      if (const ['E', 'X', 'M', 'S'].contains(secondLetter)) {
        return PlateType.gubernamental;
      }
      return PlateType.particular;
    }
    return null;
  }
}

bool isValidPlate(String plate) => PlateValidator.isValid(plate);

PlateType? classifyPlate(String plate) => PlateValidator.classify(plate);
