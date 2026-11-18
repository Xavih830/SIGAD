import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sigad/core/models/payment_model.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/repositories/payments_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/date_formatter.dart';
import 'package:sigad/features/mobile_client/presentation/widgets/policy_detail/policy_coverages_section_card.dart';
import 'package:sigad/features/mobile_client/presentation/widgets/policy_detail/policy_detail_header_card.dart';
import 'package:sigad/features/mobile_client/presentation/widgets/policy_detail/policy_info_section_card.dart';
import 'package:sigad/features/mobile_client/presentation/widgets/policy_detail/policy_installments_section_card.dart';

class PolicyDetailPage extends StatefulWidget {
  final PolicyModel policy;
  final VoidCallback onReportError;
  final String? authToken;
  final http.Client? httpClient;
  final PaymentsRepository? paymentsRepository;
  final List<PaymentModel>? initialPayments;

  const PolicyDetailPage({
    super.key,
    required this.policy,
    required this.onReportError,
    this.authToken,
    this.httpClient,
    this.paymentsRepository,
    this.initialPayments,
  });

  @override
  State<PolicyDetailPage> createState() => _PolicyDetailPageState();
}

class _PolicyDetailPageState extends State<PolicyDetailPage> {
  List<PaymentModel> _payments = [];
  bool _isLoadingPayments = true;
  String? _paymentsError;

  @override
  void initState() {
    super.initState();
    if (widget.initialPayments != null) {
      _payments = widget.initialPayments!;
      _isLoadingPayments = false;
    } else {
      _loadPayments();
    }
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoadingPayments = true;
      _paymentsError = null;
    });

    try {
      final repo = widget.paymentsRepository ?? PaymentsRepository(httpClient: widget.httpClient);
      final list = await repo.getPaymentsByPolicy(widget.policy.id, token: widget.authToken);

      if (!mounted) return;
      setState(() {
        _payments = list;
        _isLoadingPayments = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('500') ? 'No se pudieron cargar las cuotas (500)' : 'Error al cargar cuotas: $e';
      setState(() {
        _paymentsError = msg;
        _isLoadingPayments = false;
      });
    }
  }

  String get _financialStatusText =>
      PaymentModel.calculateConsolidatedStatus(_payments, defaultStatus: widget.policy.paymentStatus);

  Color get _financialStatusColor {
    if (_payments.isEmpty) return AppTheme.textMuted;
    if (_payments.any((p) => p.isOverdue)) return AppTheme.errorColor;
    return AppTheme.successColor;
  }

  @override
  Widget build(BuildContext context) {
    final policy = widget.policy;
    final veh = policy.vehicle;
    final isExp = policy.isExpired;
    final daysLeft = policy.daysUntilExpiration;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Póliza', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PolicyDetailHeaderCard(policy: policy),
            const SizedBox(height: 16),
            PolicyInfoSectionCard(
              title: 'Datos del Vehículo',
              icon: Icons.directions_car,
              rows: veh != null
                  ? [
                      PolicyInfoRowData('Marca', veh.brand),
                      PolicyInfoRowData('Modelo', veh.model),
                      PolicyInfoRowData('Año', veh.year.toString()),
                      PolicyInfoRowData('Placa', veh.plate),
                    ]
                  : [
                      const PolicyInfoRowData('Estado', 'Sin vehículo asignado'),
                    ],
            ),
            const SizedBox(height: 16),
            PolicyInfoSectionCard(
              title: 'Vigencia de Cobertura',
              icon: Icons.date_range,
              rows: [
                PolicyInfoRowData('Inicio', DateFormatter.toIsoDate(policy.startDate)),
                PolicyInfoRowData('Fin', DateFormatter.toIsoDate(policy.endDate)),
                PolicyInfoRowData(
                  'Estado',
                  isExp ? 'Expirada' : 'Quedan $daysLeft días de cobertura',
                  color: isExp ? AppTheme.errorColor : AppTheme.successColor,
                ),
              ],
            ),
            if (policy.coverages.isNotEmpty) ...[
              const SizedBox(height: 16),
              PolicyCoveragesSectionCard(coverages: policy.coverages),
            ],
            const SizedBox(height: 16),
            PolicyInfoSectionCard(
              title: 'Detalles Económicos',
              icon: Icons.payment,
              rows: [
                PolicyInfoRowData('Valor Asegurado', '\$${policy.insuredValue.toStringAsFixed(2)} USD'),
                PolicyInfoRowData('Prima Mensual', '\$${policy.monthlyPremium.toStringAsFixed(2)} USD'),
                PolicyInfoRowData('Estado Financiero', _financialStatusText, color: _financialStatusColor),
              ],
            ),
            const SizedBox(height: 16),
            PolicyInstallmentsSectionCard(
              isLoading: _isLoadingPayments,
              errorMessage: _paymentsError,
              payments: _payments,
              onRetry: _loadPayments,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onReportError();
              },
              icon: const Icon(Icons.report_problem_outlined, color: AppTheme.primaryColor),
              label: const Text('Reportar un error en la póliza', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryColor), padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
