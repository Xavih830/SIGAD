class EcuadorianIdValidator {
  /// Valida formalmente una cédula de identidad ecuatoriana (Módulo 10).
  static bool isValidCedula(String id) {
    final cleanId = id.trim();
    if (cleanId.length != 10) return false;
    if (int.tryParse(cleanId) == null) return false;

    final province = int.parse(cleanId.substring(0, 2));
    if ((province < 1 || province > 24) && province != 30) return false;

    final thirdDigit = int.parse(cleanId[2]);
    if (thirdDigit < 0 || thirdDigit > 5) return false;

    const coefficients = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    int sum = 0;

    for (int i = 0; i < 9; i++) {
      int product = int.parse(cleanId[i]) * coefficients[i];
      sum += (product >= 10) ? (product - 9) : product;
    }

    final verifierDigit = int.parse(cleanId[9]);
    final calculatedCheck = (10 - (sum % 10)) % 10;

    return verifierDigit == calculatedCheck;
  }

  /// Alias de [isValidCedula] para compatibilidad hacia atrás.
  static bool isValid(String id) => isValidCedula(id);

  /// Valida formalmente un RUC ecuatoriano de 13 dígitos según reglas SRI.
  static bool isValidRuc(String ruc) {
    final cleanRuc = ruc.trim();
    if (cleanRuc.length != 13) return false;
    if (int.tryParse(cleanRuc) == null) return false;

    final province = int.parse(cleanRuc.substring(0, 2));
    if ((province < 1 || province > 24) && province != 30) return false;

    final thirdDigit = int.parse(cleanRuc[2]);

    // 1. Persona natural: 10 dígitos de cédula válida + establecimiento >= 001
    if (thirdDigit >= 0 && thirdDigit <= 5) {
      if (!isValidCedula(cleanRuc.substring(0, 10))) return false;
      final establishment = int.parse(cleanRuc.substring(10, 13));
      return establishment >= 1;
    }

    // 2. Sociedad pública: tercer dígito 6, coeficientes Módulo 11 (8 dígitos), verificador en pos 9
    if (thirdDigit == 6) {
      const coefficients = [3, 2, 7, 6, 5, 4, 3, 2];
      int sum = 0;
      for (int i = 0; i < 8; i++) {
        sum += int.parse(cleanRuc[i]) * coefficients[i];
      }
      final remainder = sum % 11;
      final calculated = (remainder == 0) ? 0 : (11 - remainder);
      if (calculated == 10) return false;
      if (int.parse(cleanRuc[8]) != calculated) return false;
      final establishment = int.parse(cleanRuc.substring(9, 13));
      return establishment >= 1;
    }

    // 3. Sociedad privada / extranjeros: tercer dígito 9, coeficientes Módulo 11 (9 dígitos), verificador en pos 10
    if (thirdDigit == 9) {
      const coefficients = [4, 3, 2, 7, 6, 5, 4, 3, 2];
      int sum = 0;
      for (int i = 0; i < 9; i++) {
        sum += int.parse(cleanRuc[i]) * coefficients[i];
      }
      final remainder = sum % 11;
      final calculated = (remainder == 0) ? 0 : (11 - remainder);
      if (calculated == 10) return false;
      if (int.parse(cleanRuc[9]) != calculated) return false;
      final establishment = int.parse(cleanRuc.substring(10, 13));
      return establishment >= 1;
    }

    return false;
  }

  /// Valida identificación ecuatoriana: cédula (10 dígitos) o RUC (13 dígitos).
  static bool isValidIdentificacion(String id) {
    final clean = id.trim();
    if (clean.length == 10) return isValidCedula(clean);
    if (clean.length == 13) return isValidRuc(clean);
    return false;
  }
}

