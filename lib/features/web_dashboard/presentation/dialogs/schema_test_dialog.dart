import 'package:flutter/material.dart';
import 'package:sigad/core/models/extraction_schema_model.dart';
import 'package:sigad/core/repositories/extraction_schemas_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/file_picker_helper.dart';

/// Diálogo interactivo para probar reglas de esquemas OCR en memoria contra documentos reales.
class SchemaTestDialog extends StatefulWidget {
  final ExtractionSchemaModel schema;
  final ExtractionSchemasRepository? repository;
  final String? authToken;

  const SchemaTestDialog({
    super.key,
    required this.schema,
    this.repository,
    this.authToken,
  });

  @override
  State<SchemaTestDialog> createState() => _SchemaTestDialogState();
}

class _SchemaTestDialogState extends State<SchemaTestDialog> {
  late final ExtractionSchemasRepository _repo;
  SelectedFileInfo? _selectedFile;
  bool _isTesting = false;
  String? _errorMessage;
  TestSchemaResultModel? _result;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ExtractionSchemasRepository();
  }

  Future<void> _pickFile() async {
    final file = await FilePickerHelper.pickDocumentFile();
    if (file != null) {
      setState(() {
        _selectedFile = file;
        _errorMessage = null;
        _result = null;
      });
    }
  }

  Future<void> _runTest() async {
    if (_selectedFile == null) return;
    setState(() {
      _isTesting = true;
      _errorMessage = null;
    });

    try {
      final res = await _repo.testSchema(
        widget.schema.id,
        bytes: _selectedFile!.bytes,
        filename: _selectedFile!.name,
        token: widget.authToken,
      );
      if (mounted) {
        setState(() {
          _result = res;
          _isTesting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isTesting = false;
        });
      }
    }
  }

  Widget _buildResultPanel(TestSchemaResultModel res) {
    final confColor = res.confianza < 60
        ? AppTheme.errorColor
        : (res.confianza < 85 ? AppTheme.warningColor : AppTheme.successColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Método: ${res.metodo}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: confColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: confColor.withOpacity(0.4)),
              ),
              child: Text(
                'CONFIANZA: ${res.confianza.toStringAsFixed(1)}%',
                style: TextStyle(color: confColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Campos Extraídos por Reglas Regex:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (res.camposExtraidos.isEmpty)
          const Text(
            'Ninguna expresión regular coincidió con el texto del documento.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderLight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: res.camposExtraidos.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = res.camposExtraidos.entries.elementAt(index);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          entry.value?.toString() ?? '(vacío)',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (res.textoCompleto.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Texto Completo Reconocido:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                res.textoCompleto,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileSizeKb = _selectedFile != null
        ? (_selectedFile!.bytes.length / 1024).toStringAsFixed(1)
        : null;

    return AlertDialog(
      title: Text('Prueba de Calibración: ${widget.schema.nombre} (v${widget.schema.version})'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Código: ${widget.schema.codigo} • ${widget.schema.campos.length} campos configurados',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTesting ? null : _pickFile,
                    icon: const Icon(Icons.attach_file, size: 16),
                    label: const Text('Seleccionar Archivo Local'),
                  ),
                  const SizedBox(width: 12),
                  if (_selectedFile != null)
                    Expanded(
                      child: Text(
                        '${_selectedFile!.name} ($fileSizeKb KB)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Expanded(
                      child: Text(
                        'Ningún archivo seleccionado',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_selectedFile != null)
                ElevatedButton.icon(
                  onPressed: _isTesting ? null : _runTest,
                  icon: _isTesting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Ejecutar Prueba en Memoria'),
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
                  ),
                ),
              ],
              if (_result != null) _buildResultPanel(_result!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
