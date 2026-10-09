class EcuadorianIdValidator {
  static bool isValid(String id) {
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
}

