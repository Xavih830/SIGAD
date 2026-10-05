import 'package:sigad/core/utils/numeric_parser.dart';

class PaymentModel {
  final String id;
  final String policyId;
  final int installmentNumber;
  final double amountUsd;
  final DateTime dueDate;
  final DateTime? paymentDate;
  final String status; // 'pendiente', 'pagado', 'atrasado'
  final String? paymentMethod;
  final String? receiptRef;

  const PaymentModel({
    required this.id,
    required this.policyId,
    required this.installmentNumber,
    required this.amountUsd,
    required this.dueDate,
    this.paymentDate,
    required this.status,
    this.paymentMethod,
    this.receiptRef,
  });

  bool get isPaid => status.toLowerCase() == 'pagado';
  bool get isPending => status.toLowerCase() == 'pendiente';
  bool get isOverdue => status.toLowerCase() == 'atrasado';

  /// Evalúa el estado financiero consolidado a partir de una lista de cuotas.
  static String calculateConsolidatedStatus(List<PaymentModel> payments, {String? defaultStatus}) {
    if (payments.isEmpty) {
      return defaultStatus ?? 'Sin cuotas registradas';
    }
    if (payments.any((p) => p.isOverdue)) {
      return 'En mora';
    }
    if (payments.every((p) => p.isPaid)) {
      return 'Pagada';
    }
    return 'Al día';
  }

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      policyId: json['poliza_id'] as String,
      installmentNumber: json['numero_cuota'] as int,
      amountUsd: parseRequiredDouble(json['monto_usd']),
      dueDate: DateTime.parse(json['fecha_vencimiento'] as String),
      paymentDate: json['fecha_pago'] != null
          ? DateTime.parse(json['fecha_pago'] as String)
          : null,
      status: json['estado'] as String,
      paymentMethod: json['metodo_pago'] as String?,
      receiptRef: json['comprobante_ref'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'poliza_id': policyId,
      'numero_cuota': installmentNumber,
      'monto_usd': amountUsd,
      'fecha_vencimiento': dueDate.toIso8601String().substring(0, 10),
      if (paymentDate != null)
        'fecha_pago': paymentDate!.toIso8601String().substring(0, 10),
      'estado': status,
      if (paymentMethod != null) 'metodo_pago': paymentMethod,
      if (receiptRef != null) 'comprobante_ref': receiptRef,
    };
  }
}
