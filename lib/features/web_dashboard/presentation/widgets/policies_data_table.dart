import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/theme/app_theme.dart';

class PoliciesDataTable extends StatefulWidget {
  final List<PolicyModel> policies;
  final ValueChanged<PolicyModel> onViewDetail;

  const PoliciesDataTable({
    super.key,
    required this.policies,
    required this.onViewDetail,
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
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 800),
                child: DataTable(
                  columnSpacing: 28,
                  horizontalMargin: 16,
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
                  final statusNorm = p.status.toLowerCase().replaceAll('-', '_');
                  final Color statusColor;
                  final Color statusBg;
                  final String statusText;

                  switch (statusNorm) {
                    case 'activa':
                      statusColor = Colors.green.shade700;
                      statusBg = Colors.green.shade50;
                      statusText = 'ACTIVA';
                      break;
                    case 'por_vencer':
                      statusColor = Colors.orange.shade800;
                      statusBg = Colors.orange.shade50;
                      statusText = 'POR VENCER';
                      break;
                    case 'cancelada':
                      statusColor = Colors.grey.shade700;
                      statusBg = Colors.grey.shade100;
                      statusText = 'CANCELADA';
                      break;
                    case 'pendiente':
                      statusColor = Colors.blue.shade700;
                      statusBg = Colors.blue.shade50;
                      statusText = 'PENDIENTE';
                      break;
                    case 'vencida':
                    default:
                      statusColor = Colors.red.shade700;
                      statusBg = Colors.red.shade50;
                      statusText = 'VENCIDA';
                      break;
                  }

                  final vehicleParts = [
                    if (p.vehicle?.brand != null && p.vehicle!.brand.isNotEmpty) p.vehicle!.brand,
                    if (p.vehicle?.model != null && p.vehicle!.model.isNotEmpty) p.vehicle!.model,
                  ].join(' ').trim();
                  return DataRow(cells: [
                    DataCell(Text(p.number, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(p.vehicle?.plate ?? 'S/P')),
                    DataCell(Text(vehicleParts.isNotEmpty ? vehicleParts : '-')),
                    DataCell(Text(p.endDate.toIso8601String().substring(0, 10))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    )),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, color: Colors.blue, size: 20),
                          tooltip: 'Ver Detalle',
                          onPressed: () => widget.onViewDetail(p),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
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
