library;

enum ExtractionStatus {
  pendiente('pendiente'),
  procesando('procesando'),
  completado('completado'),
  revisionRequerida('revision_requerida'),
  fallido('fallido');

  final String value;
  const ExtractionStatus(this.value);

  static ExtractionStatus fromValue(String value) {
    for (final status in ExtractionStatus.values) {
      if (status.value == value) return status;
    }
    throw StateError('FAIL-FAST: Estado de extracción desconocido: "$value"');
  }
}

enum PolicyStatus {
  vigente('vigente'),
  porVencer('por_vencer'),
  vencida('vencida'),
  anulada('anulada');

  final String value;
  const PolicyStatus(this.value);

  static PolicyStatus fromValue(String value) {
    for (final status in PolicyStatus.values) {
      if (status.value == value) return status;
    }
    throw StateError('FAIL-FAST: Estado de póliza desconocido: "$value"');
  }
}

enum PaymentStatus {
  pagado('pagado'),
  pendiente('pendiente'),
  atrasado('atrasado'),
  parcial('parcial');

  final String value;
  const PaymentStatus(this.value);

  static PaymentStatus fromValue(String value) {
    for (final status in PaymentStatus.values) {
      if (status.value == value) return status;
    }
    throw StateError('FAIL-FAST: Estado de pago desconocido: "$value"');
  }
}
