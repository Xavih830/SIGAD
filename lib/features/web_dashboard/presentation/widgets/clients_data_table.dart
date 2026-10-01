import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/theme/app_theme.dart';

class ClientsDataTable extends StatefulWidget {
  final List<ClientModel> clients;
  final ValueChanged<ClientModel> onGenerateOtp;

  const ClientsDataTable({
    super.key,
    required this.clients,
    required this.onGenerateOtp,
  });

  @override
  State<ClientsDataTable> createState() => _ClientsDataTableState();
}

class _ClientsDataTableState extends State<ClientsDataTable> {
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    if (widget.clients.isEmpty) {
      return const Center(child: Text('No hay clientes registrados.'));
    }

    final totalRows = widget.clients.length;
    final totalPages = max(1, (totalRows / _rowsPerPage).ceil());
    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = min(startIndex + _rowsPerPage, totalRows);
    final displayedClients = widget.clients.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.lightBg),
                columns: const [
                  DataColumn(label: Text('Cédula', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Correo Electrónico', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Teléfono', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: displayedClients.map((c) {
                  return DataRow(cells: [
                    DataCell(Text(c.identificacion, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(c.nombres)),
                    DataCell(Text(c.email ?? '')),
                    DataCell(Text(c.telefono ?? '')),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.key, color: Colors.green, size: 20),
                          tooltip: 'Generar código OTP / WhatsApp',
                          onPressed: () => widget.onGenerateOtp(c),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mostrando ${startIndex + 1} - $endIndex de $totalRows clientes',
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              Row(
                children: [
                  const Text('Filas por página: ', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  DropdownButton<int>(
                    value: _rowsPerPage,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 25, child: Text('25')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _rowsPerPage = v;
                          _currentPage = 0;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  Text('Pág. ${_currentPage + 1} de $totalPages', style: const TextStyle(fontSize: 13)),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Página anterior',
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Página siguiente',
                    onPressed: _currentPage < totalPages - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
