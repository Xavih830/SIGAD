import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sigad/core/models/payment_model.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/repositories/payments_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';

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
      final msg = e.toString().contains('500') ? 'No se pudieron cargar las cuotas (500)' : 'Error de conexión al cargar cuotas.';
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
            Card(
              color: AppTheme.primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PÓLIZA NRO', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    const SizedBox(height: 4),
                    Text(policy.number, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('VEHÍCULO ASEGURADO', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: isExp ? Colors.red.shade400 : Colors.green.shade400, borderRadius: BorderRadius.circular(8)),
                          child: Text(isExp ? 'VENCIDA' : 'ACTIVA', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Datos del Vehículo',
              icon: Icons.directions_car,
              rows: [
                _RowData('Marca', veh?.brand ?? 'N/A'),
                _RowData('Modelo', veh?.model ?? 'N/A'),
                _RowData('Año', veh != null ? veh.year.toString() : 'N/A'),
                _RowData('Placa', veh?.plate ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Vigencia de Cobertura',
              icon: Icons.date_range,
              rows: [
                _RowData('Inicio', policy.startDate.toIso8601String().substring(0, 10)),
                _RowData('Fin', policy.endDate.toIso8601String().substring(0, 10)),
                _RowData(
                  'Estado',
                  isExp ? 'Expirada' : 'Quedan $daysLeft días de cobertura',
                  color: isExp ? AppTheme.errorColor : AppTheme.successColor,
                ),
              ],
            ),
            if (policy.coverages.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildCoveragesSection(policy.coverages),
            ],
            const SizedBox(height: 16),
            _buildSection(
              title: 'Detalles Económicos',
              icon: Icons.payment,
              rows: [
                _RowData('Valor Asegurado', '\$${policy.insuredValue.toStringAsFixed(2)} USD'),
                _RowData('Prima Mensual', '\$${policy.monthlyPremium.toStringAsFixed(2)} USD'),
                _RowData('Estado Financiero', _financialStatusText, color: _financialStatusColor),
              ],
            ),
            const SizedBox(height: 16),
            _buildPaymentsSection(),
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

  Widget _buildPaymentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 18),
              SizedBox(width: 8),
              Text(
                'Cronograma de Pagos y Cuotas',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
            ],
          ),
        ),
        if (_isLoadingPayments)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
          )
        else if (_paymentsError != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _paymentsError!,
                          style: const TextStyle(fontSize: 13, color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loadPayments,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_payments.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  'No hay cuotas registradas para esta póliza.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ),
            ),
          )
        else
          ..._payments.map((p) => _buildPaymentItemCard(p)),
      ],
    );
  }

  Widget _buildPaymentItemCard(PaymentModel payment) {
    Color badgeBg;
    Color badgeColor;
    String badgeText = payment.status.toUpperCase();

    if (payment.isPaid) {
      badgeBg = AppTheme.successColor.withOpacity(0.12);
      badgeColor = AppTheme.successColor;
    } else if (payment.isOverdue) {
      badgeBg = AppTheme.errorColor.withOpacity(0.12);
      badgeColor = AppTheme.errorColor;
    } else {
      badgeBg = AppTheme.warningColor.withOpacity(0.2);
      badgeColor = Colors.orange.shade800;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cuota ${payment.installmentNumber}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '\$${payment.amountUsd.toStringAsFixed(2)} USD',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Vence: ${payment.dueDate.toIso8601String().substring(0, 10)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                if (payment.paymentDate != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.successColor),
                  const SizedBox(width: 4),
                  Text(
                    'Pagado: ${payment.paymentDate!.toIso8601String().substring(0, 10)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.successColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
            if (payment.paymentMethod != null || payment.receiptRef != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${payment.paymentMethod ?? 'Pago'} • Ref: ${payment.receiptRef ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<_RowData> rows}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Row(children: [
            Icon(icon, color: AppTheme.primaryColor, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          ]),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: rows.asMap().entries.map((e) {
                final row = e.value;
                return Column(
                  children: [
                    if (e.key > 0) const Divider(color: AppTheme.borderLight, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(row.label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                        Text(row.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: row.color ?? AppTheme.textDark)),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoveragesSection(List<CoverageModel> coverages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Row(children: [
            Icon(Icons.verified_user, color: AppTheme.primaryColor, size: 18),
            SizedBox(width: 8),
            Text('Coberturas Contratadas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          ]),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: coverages.map((cov) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(cov.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark))),
                ]),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _RowData {
  final String label;
  final String value;
  final Color? color;
  const _RowData(this.label, this.value, {this.color});
}
