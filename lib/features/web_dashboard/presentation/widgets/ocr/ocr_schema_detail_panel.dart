import 'package:flutter/material.dart';
import 'package:sigad/core/models/extraction_schema_model.dart';
import 'package:sigad/core/theme/app_theme.dart';

class OcrSchemaDetailPanel extends StatelessWidget {
  final bool isLoading;
  final ExtractionSchemaModel? schema;
  final bool isActivating;
  final VoidCallback onTestSchema;
  final VoidCallback onActivateVersion;

  const OcrSchemaDetailPanel({
    super.key,
    required this.isLoading,
    required this.schema,
    required this.isActivating,
    required this.onTestSchema,
    required this.onActivateVersion,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (schema == null) {
      return const Center(
        child: Text(
          'Selecciona un esquema para ver sus reglas y campos.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    final currentSchema = schema!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentSchema.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código: ${currentSchema.codigo} • Versión: ${currentSchema.version}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    if (currentSchema.descripcion != null && currentSchema.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        currentSchema.descripcion!,
                        style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onTestSchema,
                    icon: const Icon(Icons.science_outlined, size: 16),
                    label: const Text('Probar con Documento'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentSchema.esActivo ? Colors.grey : AppTheme.successColor,
                    ),
                    onPressed: (currentSchema.esActivo || isActivating) ? null : onActivateVersion,
                    icon: isActivating
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                    label: Text(
                      currentSchema.esActivo ? 'Versión Activa' : 'Activar Versión',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 32),
          Text(
            'Campos y Reglas Regex (${currentSchema.campos.length}):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (currentSchema.campos.isEmpty)
            const Text(
              'Este esquema no tiene campos configurados.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            )
          else
            Table(
              border: TableBorder.all(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(6)),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(4),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(padding: EdgeInsets.all(8), child: Text('CAMPO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: EdgeInsets.all(8), child: Text('EXPRESIÓN REGULAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: EdgeInsets.all(8), child: Text('TIPO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(padding: EdgeInsets.all(8), child: Text('REQUERIDO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
                for (final c in currentSchema.campos)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: SelectableText(
                          c.regex,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.indigo),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(c.tipo, style: const TextStyle(fontSize: 12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          c.esObligatorio ? 'SÍ' : 'NO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: c.esObligatorio ? AppTheme.errorColor : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
