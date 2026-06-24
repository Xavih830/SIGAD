class EcuadorianIdValidator {
  static bool isValid(String id) {
    if (id.length != 10) return false;
    if (int.tryParse(id) == null) return false;

    // First two digits represent province (01 to 24, or 30)
    final province = int.parse(id.substring(0, 2));
    if (province < 1 || (province > 24 && province != 30)) return false;

    return true;
  }
}
