import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PolicyDetailPage extends StatelessWidget {
  final Map<String, dynamic> policy;
  final VoidCallback onReportError;

  const PolicyDetailPage({
    super.key,
    required this.policy,
    required this.onReportError,
  });

  int _calculateDaysLeft(String endDateStr) {
    try {
      final endDate = DateTime.parse(endDateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiry = DateTime(endDate.year, endDate.month, endDate.day);
      return expiry.difference(today).inDays;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = _calculateDaysLeft(policy['endDate']);
    final isExpired = daysLeft <= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detalle de Póliza',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Card(
              color: AppTheme.primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PÓLIZA NRO',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      policy['number'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          policy['type'] == 'pesado' ? 'VEHÍCULO PESADO' : 'VEHÍCULO LIVIANO',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isExpired ? Colors.red.shade400 : Colors.green.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isExpired ? 'VENCIDA' : 'ACTIVA',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Section 1: Vehicle Data
            _buildSectionHeader(context, 'Datos del Vehículo', Icons.directions_car),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow('Marca', policy['vehicleBrand']),
                    _buildDetailDivider(),
                    _buildDetailRow('Modelo', policy['vehicleModel']),
                    _buildDetailDivider(),
                    _buildDetailRow('Año', policy['vehicleYear'].toString()),
                    _buildDetailDivider(),
                    _buildDetailRow('Color', policy['vehicleColor']),
                    _buildDetailDivider(),
                    _buildDetailRow('Placa', policy['plate']),
                    if (policy['type'] == 'pesado' && policy['tonnage'] != null) ...[
                      _buildDetailDivider(),
                      _buildDetailRow('Tonelaje', '${policy['tonnage']} t'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Vigencia
            _buildSectionHeader(context, 'Vigencia de Cobertura', Icons.date_range),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow('Inicio de Vigencia', policy['startDate']),
                    _buildDetailDivider(),
                    _buildDetailRow('Fin de Vigencia', policy['endDate']),
                    _buildDetailDivider(),
                    _buildDetailRow(
                      'Estado de Vigencia',
                      isExpired ? 'Expirada' : 'Quedan $daysLeft días de cobertura',
                      valueColor: isExpired ? AppTheme.errorColor : AppTheme.successColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Coverages
            _buildSectionHeader(context, 'Coberturas Contratadas', Icons.verified_user),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...(policy['coverages'] as List).map((coverage) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                coverage.toString(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 4: Payments
            _buildSectionHeader(context, 'Detalles de Pago', Icons.payment),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow('Valor Asegurado', '\$${(policy['value'] as double).toStringAsFixed(2)} USD'),
                    _buildDetailDivider(),
                    _buildDetailRow('Prima Mensual', '\$${(policy['prima'] as double).toStringAsFixed(2)} USD'),
                    _buildDetailDivider(),
                    _buildDetailRow(
                      'Estado del Pago',
                      policy['paymentStatus'] ?? 'Al día',
                      valueColor: AppTheme.successColor,
                    ),
                    _buildDetailDivider(),
                    _buildDetailRow('Último Pago Registrado', policy['lastPaymentDate'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Report Error Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onReportError();
              },
              icon: const Icon(Icons.report_problem_outlined, color: AppTheme.primaryColor),
              label: const Text(
                'Reportar un error',
                style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailDivider() {
    return const Divider(color: AppTheme.borderLight, height: 12, thickness: 0.5);
  }
}
