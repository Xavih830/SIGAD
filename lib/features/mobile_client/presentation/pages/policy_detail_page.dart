import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/theme/app_theme.dart';

class PolicyDetailPage extends StatelessWidget {
  final PolicyModel policy;
  final VoidCallback onReportError;

  const PolicyDetailPage({
    super.key,
    required this.policy,
    required this.onReportError,
  });

  @override
  Widget build(BuildContext context) {
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
                _RowData('Estado de Pago', policy.paymentStatus ?? 'Al día', color: AppTheme.successColor),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onReportError();
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

  Widget _buildSection({required String title, required IconData icon, required List<_RowData> rows}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Row(children: [Icon(icon, color: AppTheme.primaryColor, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark))]),
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

  Widget _buildCoveragesSection(List<String> coverages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Row(children: [Icon(Icons.verified_user, color: AppTheme.primaryColor, size: 18), SizedBox(width: 8), Text('Coberturas Contratadas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark))]),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: coverages.map((cov) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(children: [const Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 18), const SizedBox(width: 10), Expanded(child: Text(cov, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)))]),
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
