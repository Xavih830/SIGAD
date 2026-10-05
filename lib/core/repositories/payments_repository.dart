import 'package:http/http.dart' as http;
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/models/payment_model.dart';
import 'package:sigad/core/network/api_client.dart';

/// Repositorio canónico para consulta y registro de cuotas y pagos de pólizas (HU-20).
class PaymentsRepository {
  final ApiClient _client;

  PaymentsRepository({ApiClient? client, http.Client? httpClient})
      : _client = client ?? ApiClient(client: httpClient);

  Future<List<PaymentModel>> getPaymentsByPolicy(String policyId, {String? token}) async {
    final list = await _client.getList(ApiEndpoints.polizaPagos(policyId), token: token);
    final payments = list.map((e) => PaymentModel.fromJson(e)).toList();
    payments.sort((a, b) => a.installmentNumber.compareTo(b.installmentNumber));
    return payments;
  }

  Future<PaymentModel> registerPayment({
    required String policyId,
    required String paymentId,
    required String paymentMethod,
    required String receiptRef,
    DateTime? paymentDate,
    String? token,
  }) async {
    final payload = {
      'metodo_pago': paymentMethod,
      'comprobante_ref': receiptRef,
      if (paymentDate != null)
        'fecha_pago': paymentDate.toIso8601String().substring(0, 10),
    };

    final data = await _client.post(
      ApiEndpoints.polizaRegistrarPago(policyId, paymentId),
      body: payload,
      token: token,
    );
    return PaymentModel.fromJson(data);
  }
}
