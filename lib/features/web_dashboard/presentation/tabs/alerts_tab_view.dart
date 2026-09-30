import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/services/hive_helper.dart';
import 'package:sigad/core/theme/app_theme.dart';

class AlertsTabView extends StatefulWidget {
  const AlertsTabView({super.key});

  @override
  State<AlertsTabView> createState() => _AlertsTabViewState();
}

class _AlertsTabViewState extends State<AlertsTabView> {
  int _thresholdDays = 30;

  List<PolicyModel> _getExpiringPolicies() {
    final raw = HiveHelper.policiesBox.values
        .map((p) => Map<String, dynamic>.from(p))
        .where((p) => p['isDeleted'] != true)
        .toList();

    return raw.map((m) => PolicyModel.fromJson(m)).where((p) {
      return !p.isExpired && p.daysUntilExpiration <= _thresholdDays && p.daysUntilExpiration >= 0;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final expiring = _getExpiringPolicies();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pólizas Próximas a Vencer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('Umbral: ', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                    DropdownButton<int>(
                      value: _thresholdDays,
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 días')),
                        DropdownMenuItem(value: 30, child: Text('30 días')),
                        DropdownMenuItem(value: 60, child: Text('60 días')),
                        DropdownMenuItem(value: 90, child: Text('90 días')),
                      ],
                      onChanged: (v) => setState(() => _thresholdDays = v ?? 30),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: expiring.isEmpty
                  ? Center(child: Text('No hay pólizas por vencer en los próximos $_thresholdDays días.', style: const TextStyle(color: AppTheme.textMuted)))
                  : ListView.builder(
                      itemCount: expiring.length,
                      itemBuilder: (ctx, i) {
                        final p = expiring[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppTheme.warningColor.withOpacity(0.15), shape: BoxShape.circle),
                              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
                            ),
                            title: Text('${p.number} - ${p.vehicle?.brand ?? ''} ${p.vehicle?.model ?? ''} (${p.vehicle?.plate ?? 'S/P'})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('Vence el: ${p.endDate.toIso8601String().substring(0, 10)}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                              child: Text('Quedan ${p.daysUntilExpiration} días', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
