import 'package:flutter/material.dart';
import 'package:sigad/core/models/extraction_schema_model.dart';
import 'package:sigad/core/theme/app_theme.dart';

class OcrSchemaReextractionBar extends StatelessWidget {
  final List<ExtractionSchemaListItemModel> extractionSchemas;
  final String? selectedSchemaId;
  final bool isReExtracting;
  final ValueChanged<String?> onSchemaChanged;
  final VoidCallback onReExtract;

  const OcrSchemaReextractionBar({
    super.key,
    required this.extractionSchemas,
    required this.selectedSchemaId,
    required this.isReExtracting,
    required this.onSchemaChanged,
    required this.onReExtract,
  });

  @override
  Widget build(BuildContext context) {
    if (extractionSchemas.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.lightBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Extractor / Esquema OCR Alternativo:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedSchemaId,
                  decoration: const InputDecoration(
                    labelText: 'Seleccionar Esquema de Extracción',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: extractionSchemas
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.nombre} (v${s.version}) ${s.esActivo ? "[Activo]" : ""}'),
                          ))
                      .toList(),
                  onChanged: onSchemaChanged,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: (isReExtracting || selectedSchemaId == null)
                    ? null
                    : onReExtract,
                icon: isReExtracting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync, size: 16),
                label: const Text('Re-extraer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
