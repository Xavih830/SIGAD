import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/theme/app_theme.dart';

class PoliciesDataTable extends StatelessWidget {
  final List<PolicyModel> policies;
  final ValueChanged<PolicyModel> onEdit;

  const PoliciesDataTable({
    super.key,
    required this.policies,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (policies.isEmpty) return const Center(child: Text('No se encontraron pólizas registradas.'));

    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.lightBg),
        columns: const [
          DataColumn(label: Text('Nro. Póliza', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Placa', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Vehículo', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Fin Vigencia', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: policies.map((p) {
          final isExp = p.isExpired;
          return DataRow(cells: [
            DataCell(Text(p.number, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(p.vehicle?.plate ?? 'S/P')),
            DataCell(Text('${p.vehicle?.brand ?? ''} ${p.vehicle?.model ?? ''}'.trim())),
            DataCell(Text(p.endDate.toIso8601String().substring(0, 10))),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isExp ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(isExp ? 'VENCIDA' : p.status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isExp ? Colors.red.shade700 : Colors.green.shade700)),
            )),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20), tooltip: 'Editar', onPressed: () => onEdit(p)),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }
}
