import 'package:flutter/material.dart';
import 'package:sigad/core/models/extraction_schema_model.dart';
import 'package:sigad/core/theme/app_theme.dart';

class OcrSchemasListPanel extends StatelessWidget {
  final bool isLoading;
  final List<ExtractionSchemaListItemModel> schemas;
  final String? selectedSchemaId;
  final ValueChanged<String> onSelectSchema;

  const OcrSchemasListPanel({
    super.key,
    required this.isLoading,
    required this.schemas,
    required this.selectedSchemaId,
    required this.onSelectSchema,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (schemas.isEmpty) {
      return const Center(
        child: Text(
          'No existen esquemas de extracción registrados.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    return ListView.separated(
      itemCount: schemas.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = schemas[index];
        final isSelected = selectedSchemaId == item.id;

        return ListTile(
          selected: isSelected,
          selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.08),
          title: Text(
            item.nombre,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            '${item.codigo} • v${item.version}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: item.esActivo
                  ? AppTheme.successColor.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: item.esActivo
                    ? AppTheme.successColor.withValues(alpha: 0.4)
                    : Colors.grey.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              item.esActivo ? 'ACTIVO' : 'INACTIVO',
              style: TextStyle(
                color: item.esActivo ? AppTheme.successColor : Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: () => onSelectSchema(item.id),
        );
      },
    );
  }
}
