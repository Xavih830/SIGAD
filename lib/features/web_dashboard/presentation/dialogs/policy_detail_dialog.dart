import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/theme/app_theme.dart';

class PolicyDetailDialog extends StatelessWidget {
  final PolicyModel policy;
  final ValueChanged<String>? onStatusChange;

  const PolicyDetailDialog({
    super.key,
    required this.policy,
    this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final veh = policy.vehicle;
    final vehicleDesc = [
      if (veh?.brand != null && veh!.brand.isNotEmpty) veh.brand,
      if (veh?.model != null && veh!.model.isNotEmpty) veh.model,
      if (veh?.year != null) '(${veh!.year})',
    ].join(' ').trim();

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text('Póliza: ${policy.number}'),
            ],
          ),
          _buildStatusBadge(policy.status),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Información del Vehículo'),
              _buildInfoRow('Placa:', veh != null ? veh.plate : 'Sin placa asignada'),
              _buildInfoRow('Vehículo:', vehicleDesc.isNotEmpty ? vehicleDesc : 'No especificado'),
              const Divider(height: 24),
              _buildSectionTitle('Condiciones Contractuales'),
              _buildInfoRow('Valor Asegurado:', '\$${policy.insuredValue.toStringAsFixed(2)} USD'),
              _buildInfoRow('Prima Mensual:', '\$${policy.monthlyPremium.toStringAsFixed(2)} USD'),
              _buildInfoRow('Kilometraje de Emisión:', '${policy.emissionMileage} km'),
              _buildInfoRow('Vigencia:', '${policy.startDate.toIso8601String().substring(0, 10)}  al  ${policy.endDate.toIso8601String().substring(0, 10)}'),
              const Divider(height: 24),
              _buildSectionTitle('Coberturas Contratadas'),
              if (policy.coverages.isEmpty)
                const Text('Sin coberturas adicionales.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: policy.coverages.map((c) => Chip(
                    label: Text(c.nombre, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppTheme.lightBg,
                  )).toList(),
                ),
              if (policy.deductibles.isNotEmpty) ...[
                const Divider(height: 24),
                _buildSectionTitle('Deducibles Diferenciados (SC-2026-001)'),
                ...policy.deductibles.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('• ${d.tipoSiniestro.toUpperCase()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('${d.porcentajeValor}% (Mín. \$${d.montoMinimoUsd.toStringAsFixed(2)})', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (onStatusChange != null && policy.status.toLowerCase() != 'cancelada')
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            label: const Text('Cancelar Póliza', style: TextStyle(color: Colors.red)),
            onPressed: () => _confirmCancellation(context),
          ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final norm = status.toLowerCase().replaceAll('-', '_');
    final Color color;
    final Color bg;
    final String text;

    switch (norm) {
      case 'activa':
        color = Colors.green.shade700;
        bg = Colors.green.shade50;
        text = 'ACTIVA';
        break;
      case 'por_vencer':
        color = Colors.orange.shade800;
        bg = Colors.orange.shade50;
        text = 'POR VENCER';
        break;
      case 'cancelada':
        color = Colors.grey.shade700;
        bg = Colors.grey.shade100;
        text = 'CANCELADA';
        break;
      case 'pendiente':
        color = Colors.blue.shade700;
        bg = Colors.blue.shade50;
        text = 'PENDIENTE';
        break;
      case 'vencida':
      default:
        color = Colors.red.shade700;
        bg = Colors.red.shade50;
        text = 'VENCIDA';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  void _confirmCancellation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Cancelación'),
        content: Text('¿Está seguro de que desea cancelar formalmente la póliza ${policy.number}? Esta acción modificará su estado contractual.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              onStatusChange?.call('cancelada');
            },
            child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
