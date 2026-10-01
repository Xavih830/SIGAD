import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/theme/app_theme.dart';

class PoliciesDataTable extends StatefulWidget {
  final List<PolicyModel> policies;
  final ValueChanged<PolicyModel> onEdit;

  const PoliciesDataTable({
    super.key,
    required this.policies,
    required this.onEdit,
  });

  @override
  State<PoliciesDataTable> createState() => _PoliciesDataTableState();
}

class _PoliciesDataTableState extends State<PoliciesDataTable> {
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    if (widget.policies.isEmpty) {
      return const Center(child: Text('No se encontraron pólizas registradas.'));
    }

    final totalRows = widget.policies.length;
    final totalPages = max(1, (totalRows / _rowsPerPage).ceil());
    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = min(startIndex + _rowsPerPage, totalRows);
    final displayedPolicies = widget.policies.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
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
                rows: displayedPolicies.map((p) {
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
                      child: Text(
                        isExp ? 'VENCIDA' : p.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isExp ? Colors.red.shade700 : Colors.green.shade700,
                        ),
                      ),
                    )),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                          tooltip: 'Editar',
                          onPressed: () => widget.onEdit(p),
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
                'Mostrando ${startIndex + 1} - $endIndex de $totalRows pólizas',
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
