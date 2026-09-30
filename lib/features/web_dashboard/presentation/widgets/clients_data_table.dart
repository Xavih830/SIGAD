import 'package:flutter/material.dart';
import 'package:sigad/core/theme/app_theme.dart';

class ClientsDataTable extends StatelessWidget {
  final List<Map<String, dynamic>> clients;
  final ValueChanged<Map<String, dynamic>> onGenerateOtp;

  const ClientsDataTable({
    super.key,
    required this.clients,
    required this.onGenerateOtp,
  });

  @override
  Widget build(BuildContext context) {
    if (clients.isEmpty) return const Center(child: Text('No hay clientes registrados.'));
    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.lightBg),
        columns: const [
          DataColumn(label: Text('Cédula', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Correo Electrónico', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Teléfono', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: clients.map((c) {
          final id = c['identificacion']?.toString() ?? c['id']?.toString() ?? '';
          return DataRow(cells: [
            DataCell(Text(id, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(c['nombres']?.toString() ?? c['name']?.toString() ?? '')),
            DataCell(Text(c['email']?.toString() ?? '')),
            DataCell(Text(c['telefono']?.toString() ?? c['phone']?.toString() ?? '')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.key, color: Colors.green, size: 20),
                  tooltip: 'Generar código OTP / WhatsApp',
                  onPressed: () => onGenerateOtp(c),
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }
}
