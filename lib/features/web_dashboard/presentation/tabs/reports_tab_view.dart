import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sigad/core/services/hive_helper.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/print/print_helper.dart';

class ReportsTabView extends StatefulWidget {
  const ReportsTabView({super.key});

  @override
  State<ReportsTabView> createState() => _ReportsTabViewState();
}

class _ReportsTabViewState extends State<ReportsTabView> {
  void _printReport() {
    if (kIsWeb) {
      triggerPrint();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La exportación por impresión solo está disponible en entorno Web.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawPolicies = HiveHelper.policiesBox.values
        .map((p) => Map<String, dynamic>.from(p))
        .where((p) => p['isDeleted'] != true)
        .toList();

    final totalCount = rawPolicies.length;
    final activeCount = rawPolicies.where((p) => p['status'] == 'activa').length;
    final totalInsured = rawPolicies.fold<double>(0.0, (acc, p) => acc + ((p['value'] ?? p['valor_asegurado'] ?? 0) as num).toDouble());
    final totalPremiums = rawPolicies.fold<double>(0.0, (acc, p) => acc + ((p['prima'] ?? p['prima_mensual'] ?? 0) as num).toDouble());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Métricas Generales de Cartera', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _printReport,
                  icon: const Icon(Icons.print),
                  label: const Text('Exportar / Imprimir'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _kpi('Total Pólizas', totalCount.toString(), Icons.folder_shared, Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: _kpi('Pólizas Activas', activeCount.toString(), Icons.verified, Colors.green)),
                const SizedBox(width: 16),
                Expanded(child: _kpi('Capital Asegurado', '\$${totalInsured.toStringAsFixed(2)}', Icons.shield, Colors.deepPurple)),
                const SizedBox(width: 16),
                Expanded(child: _kpi('Primas Mensuales', '\$${totalPremiums.toStringAsFixed(2)}', Icons.monetization_on, Colors.teal)),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Desglose por Estado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: const Text('Pólizas Vigentes'),
                    trailing: Text('$activeCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const Divider(color: AppTheme.borderLight),
                  ListTile(
                    leading: const Icon(Icons.warning, color: Colors.orange),
                    title: const Text('Pólizas Vencidas / Por Renovar'),
                    trailing: Text('${totalCount - activeCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String val, IconData icon, Color col) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: col.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: col.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: col, size: 28),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: col)),
        ],
      ),
    );
  }
}
