import 'package:flutter/material.dart';
import 'package:sigad/core/theme/app_theme.dart';

class OcrEditableFieldsList extends StatelessWidget {
  final Map<String, TextEditingController> controllers;
  final bool isSaving;
  final VoidCallback onSaveRevision;
  final VoidCallback onLinkPolicy;

  const OcrEditableFieldsList({
    super.key,
    required this.controllers,
    required this.isSaving,
    required this.onSaveRevision,
    required this.onLinkPolicy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            const Text(
              'Campos Extraídos (Editables para Corrección):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onSaveRevision,
                  icon: isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check, size: 16),
                  label: const Text('Confirmar Correcciones'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                  onPressed: onLinkPolicy,
                  icon: const Icon(Icons.add_task, color: Colors.white, size: 16),
                  label: const Text('Vincular a Póliza', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (controllers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              'No se detectaron campos estructurados en este documento.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          )
        else
          for (final entry in controllers.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 160,
                    child: Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
