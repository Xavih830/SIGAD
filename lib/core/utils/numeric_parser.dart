double parseRequiredDouble(dynamic value) {
  if (value == null) {
    throw TypeError();
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.parse(value);
  }
  throw TypeError();
}

double? parseOptionalDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.parse(value);
  }
  throw TypeError();
}
