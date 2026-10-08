import 'package:flutter/material.dart';
import 'package:sigad/core/models/document_model.dart';
import 'package:sigad/core/theme/app_theme.dart';

class OcrDocumentListPanel extends StatelessWidget {
  final List<DocumentModel> documentos;
  final String? selectedId;
  final bool isLoading;
  final bool isUploading;
  final VoidCallback onRefresh;
  final VoidCallback onUpload;
  final ValueChanged<String> onSelect;

  const OcrDocumentListPanel({
    super.key,
    required this.documentos,
    required this.selectedId,
    required this.isLoading,
    required this.isUploading,
    required this.onRefresh,
    required this.onUpload,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.document_scanner, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  'Documentos OCR',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Refrescar',
              onPressed: isLoading ? null : onRefresh,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: isUploading ? null : onUpload,
          icon: isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.upload_file, color: Colors.white),
          label: Text(
            isUploading ? 'Subiendo...' : 'Cargar Archivo',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: AppTheme.borderLight, height: 1),
        const SizedBox(height: 12),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : documentos.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay documentos registrados',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      itemCount: documentos.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: AppTheme.borderLight),
                      itemBuilder: (ctx, index) {
                        final doc = documentos[index];
                        final isSelected = selectedId != null && selectedId == doc.id;
                        final tamKb = (doc.tamanoBytes / 1024).toStringAsFixed(1);
                        final dateStr = doc.createdAt.toIso8601String().substring(0, 10);
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          leading: const Icon(Icons.description_outlined, color: AppTheme.textMuted),
                          title: Text(
                            doc.nombreArchivo,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '$tamKb KB • $dateStr',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                          onTap: () => onSelect(doc.id),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
