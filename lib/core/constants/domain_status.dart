library;

enum ExtractionStatus {
  pendiente('pendiente', 'Pendiente'),
  procesando('procesando', 'Procesando'),
  completado('completado', 'Completado'),
  requiereRevisionManual('requiere_revision_manual', 'Requiere Revisión Manual'),
  error('error', 'Error'),
  errorPermanente('error_permanente', 'Error Permanente');

  final String value;
  final String label;
  const ExtractionStatus(this.value, this.label);

  static ExtractionStatus fromValue(String value) {
    for (final status in ExtractionStatus.values) {
      if (status.value == value) return status;
    }
    throw StateError('FAIL-FAST: Estado de extracción desconocido: "$value"');
  }
}

enum PolicyStatus {
  pendiente('pendiente', 'Pendiente'),
  activa('activa', 'Activa'),
  porVencer('por_vencer', 'Por Vencer'),
  vencida('vencida', 'Vencida'),
  cancelada('cancelada', 'Cancelada');

  final String value;
  final String label;
  const PolicyStatus(this.value, this.label);

  static PolicyStatus fromValue(String value) {
    for (final status in PolicyStatus.values) {
      if (status.value == value) return status;
    }
    throw StateError('FAIL-FAST: Estado de póliza desconocido: "$value"');
  }
}

enum PaymentStatus {
  pendiente('pendiente', 'Pendiente'),
  pagado('pagado', 'Pagado'),
  atrasado('atrasado', 'Atrasado');

  final String value;
  final String label;
  const PaymentStatus(this.value, this.label);

  static PaymentStatus fromValue(String value) {
    for (final status in PaymentStatus.values) {
      if (status.value == value) return status;
    }
    throw StateError('FAIL-FAST: Estado de pago desconocido: "$value"');
  }
}
