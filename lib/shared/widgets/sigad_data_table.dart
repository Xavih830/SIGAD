import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sigad/core/theme/app_theme.dart';

class SigadColumn<T> {
  final Widget label;
  final Widget Function(T item) cellBuilder;
  final bool numeric;

  const SigadColumn({
    required this.label,
    required this.cellBuilder,
    this.numeric = false,
  });
}

class SigadDataTable<T> extends StatelessWidget {
  final List<SigadColumn<T>> columns;
  final List<T> rows;
  final bool isLoading;
  final String emptyMessage;
  final int? total;
  final int? skip;
  final int? limit;
  final ValueChanged<int>? onPageChanged;

  const SigadDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.emptyMessage = 'No hay datos disponibles.',
    this.total,
    this.skip,
    this.limit,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            emptyMessage,
            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    final hasPagination = total != null && skip != null && limit != null && onPageChanged != null;
    final int effectiveSkip = skip ?? 0;
    final int effectiveLimit = limit ?? 10;
    final int effectiveTotal = total ?? rows.length;

    final startDisplay = rows.isEmpty ? 0 : effectiveSkip + 1;
    final endDisplay = min(effectiveSkip + rows.length, effectiveTotal);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.lightBg),
                columns: columns.map((col) {
                  return DataColumn(
                    label: col.label,
                    numeric: col.numeric,
                  );
                }).toList(),
                rows: rows.map((item) {
                  return DataRow(
                    cells: columns.map((col) {
                      return DataCell(col.cellBuilder(item));
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        if (hasPagination) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mostrando $startDisplay–$endDisplay de $effectiveTotal',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Página anterior',
                      onPressed: effectiveSkip > 0
                          ? () => onPageChanged!(max(0, effectiveSkip - effectiveLimit))
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Página siguiente',
                      onPressed: (effectiveSkip + effectiveLimit < effectiveTotal)
                          ? () => onPageChanged!(effectiveSkip + effectiveLimit)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
