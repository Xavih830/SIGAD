import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/repositories/policies_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/date_formatter.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_certificate_dialog.dart';

class PolicyDetailDialog extends StatefulWidget {
  final PolicyModel policy;
  final ValueChanged<String>? onStatusChange;
  final VoidCallback? onEdit;
  final PoliciesRepository? policiesRepository;
  final String? authToken;
  final List<PolicyHistoryEntry>? initialHistory;

  const PolicyDetailDialog({
    super.key,
    required this.policy,
    this.onStatusChange,
    this.onEdit,
    this.policiesRepository,
    this.authToken,
    this.initialHistory,
  });

  @override
  State<PolicyDetailDialog> createState() => _PolicyDetailDialogState();
}

class _PolicyDetailDialogState extends State<PolicyDetailDialog> {
  List<PolicyHistoryEntry> _history = [];
  bool _loadingHistory = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    if (widget.initialHistory != null) {
      _history = widget.initialHistory!;
    } else if (widget.policiesRepository != null) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final items = await widget.policiesRepository!.getPolicyHistory(
        widget.policy.id,
        token: widget.authToken,
      );
      if (!mounted) return;
      setState(() {
        _history = items;
        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.toString();
        _loadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = widget.policy;

    return DefaultTabController(
      length: 4,
      child: AlertDialog(
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
          width: 640,
          height: 440,
          child: Column(
            children: [
              const TabBar(
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.textMuted,
                tabs: [
                  Tab(text: 'Datos'),
                  Tab(text: 'Coberturas'),
                  Tab(text: 'Documentos'),
                  Tab(text: 'Historial'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildDatosTab(policy),
                    _buildCoberturasTab(policy),
                    _buildDocumentosTab(policy),
                    _buildHistorialTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.onEdit != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
              label: const Text('Editar', style: TextStyle(color: AppTheme.primaryColor)),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onEdit!();
              },
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined, color: AppTheme.primaryColor),
            label: const Text('Exportar Certificado', style: TextStyle(color: AppTheme.primaryColor)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => PolicyCertificateDialog(policy: policy),
              );
            },
          ),
          if (widget.onStatusChange != null && policy.status.toLowerCase() != 'cancelada')
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
      ),
    );
  }

  Widget _buildDatosTab(PolicyModel policy) {
    final veh = policy.vehicle;
    final vehicleDesc = [
      if (veh?.brand != null && veh!.brand.isNotEmpty) veh.brand,
      if (veh?.model != null && veh!.model.isNotEmpty) veh.model,
      if (veh?.year != null) '(${veh!.year})',
    ].join(' ').trim();

    return SingleChildScrollView(
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
          _buildInfoRow('Vigencia:', '${DateFormatter.toIsoDate(policy.startDate)}  al  ${DateFormatter.toIsoDate(policy.endDate)}'),
          _buildInfoRow('Versión:', 'v${policy.version}'),
          if (policy.camposAdicionales != null && policy.camposAdicionales!.isNotEmpty) ...[
            const Divider(height: 24),
            _buildSectionTitle('Especificaciones Específicas del Esquema'),
            ...policy.camposAdicionales!.entries.map((e) {
              final displayKey = e.key
                  .split('_')
                  .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
                  .join(' ');
              final displayVal = e.value is bool ? (e.value ? 'Sí' : 'No') : '${e.value}';
              return _buildInfoRow('$displayKey:', displayVal);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCoberturasTab(PolicyModel policy) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionTitle('Coberturas Contratadas'),
          if (policy.coverages.isEmpty)
            const Text('Sin coberturas adicionales.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13))
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: policy.coverages
                  .map((c) => Chip(
                        label: Text('${c.nombre} (\$${c.monto.toStringAsFixed(2)})', style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppTheme.lightBg,
                      ))
                  .toList(),
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
    );
  }

  Widget _buildDocumentosTab(PolicyModel policy) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open_outlined, size: 40, color: AppTheme.textMuted),
          const SizedBox(height: 8),
          Text(
            'Documentos asociados a la póliza ${policy.number}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gestione los PDF y respaldos desde la pestaña Lector Documental OCR.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_historyError != null) {
      return Center(child: Text('Error al cargar historial: $_historyError', style: const TextStyle(color: AppTheme.errorColor)));
    }
    if (_history.isEmpty) {
      return const Center(
        child: Text('No existen modificaciones registradas para esta póliza.', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return ListView.separated(
      itemCount: _history.length,
      separatorBuilder: (_, _) => const Divider(height: 12),
      itemBuilder: (context, index) {
        final h = _history[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.history, size: 20, color: AppTheme.primaryColor),
          title: Text(
            'Campo: ${h.campo}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            'Anterior: ${h.valorAnterior ?? "-"}  →  Nuevo: ${h.valorNuevo ?? "-"}\n'
            'Usuario: ${h.usuarioId ?? "Sistema"} • ${DateFormatter.toIsoDate(h.fecha)}',
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
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
        content: Text('¿Está seguro de que desea cancelar formalmente la póliza ${widget.policy.number}? Esta acción modificará su estado contractual.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              widget.onStatusChange?.call('cancelada');
            },
            child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
