import 'package:flutter/material.dart';
import 'package:sigad/core/models/document_model.dart';
import 'package:sigad/core/repositories/documents_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';

class OcrDocumentDetailCard extends StatefulWidget {
  final DocumentModel? document;
  final bool isLoading;
  final VoidCallback onRefresh;
  final Function(Map<String, dynamic> confirmedFields) onLinkPolicy;
  final String authToken;
  final DocumentsRepository? documentsRepository;

  const OcrDocumentDetailCard({
    super.key,
    required this.document,
    required this.isLoading,
    required this.onRefresh,
    required this.onLinkPolicy,
    required this.authToken,
    this.documentsRepository,
  });

  @override
  State<OcrDocumentDetailCard> createState() => _OcrDocumentDetailCardState();
}

class _OcrDocumentDetailCardState extends State<OcrDocumentDetailCard> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant OcrDocumentDetailCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.document != oldWidget.document) {
      _initControllers();
    }
  }

  void _initControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();

    final campos = widget.document?.camposExtraidos ?? {};
    for (final entry in campos.entries) {
      _controllers[entry.key] = TextEditingController(text: entry.value?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardarRevision() async {
    if (widget.document == null) return;
    final docId = widget.document!.id;

    setState(() => _isSaving = true);
    final updatedCampos = <String, dynamic>{};
    _controllers.forEach((key, ctrl) {
      updatedCampos[key] = ctrl.text.trim();
    });

    try {
      final repo = widget.documentsRepository ?? DocumentsRepository();
      await repo.confirmRevision(
        documentId: docId,
        camposCorregidos: updatedCampos,
        token: widget.authToken,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campos OCR revisados y confirmados con éxito.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar revisión: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildStatusBadge(String estado) {
    Color color = AppTheme.textMuted;
    switch (estado.toLowerCase()) {
      case 'completado':
        color = AppTheme.successColor;
        break;
      case 'procesando':
      case 'pendiente':
        color = AppTheme.warningColor;
        break;
      case 'revision_requerida':
        color = Colors.indigo;
        break;
      case 'error':
      case 'fallido':
      case 'error_permanente':
        color = AppTheme.errorColor;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildConfidenceBadge(double? c) {
    if (c == null) return const SizedBox.shrink();
    final color = c < 60 ? AppTheme.errorColor : (c < 85 ? AppTheme.warningColor : AppTheme.successColor);
    final nivel = c < 60 ? 'BAJA' : (c < 85 ? 'MEDIA' : 'ALTA');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        'CONFIANZA $nivel (${c.toStringAsFixed(1)}%)',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPendingBanner(String estado) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Documento en estado "$estado". Se procesará en segundo plano.',
              style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
            ),
          ),
          TextButton.icon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultContent(DocumentModel doc) {
    final metodo = doc.metodo ?? 'desconocido';
    final confianza = doc.confianza;
    final texto = doc.textoCompleto ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Método: $metodo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            _buildConfidenceBadge(confianza),
          ],
        ),
        const Divider(height: 24, color: AppTheme.borderLight),
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
                  onPressed: _isSaving ? null : _guardarRevision,
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check, size: 16),
                  label: const Text('Confirmar Correcciones'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                  onPressed: () {
                    final currentValues = <String, dynamic>{};
                    _controllers.forEach((k, v) => currentValues[k] = v.text.trim());
                    widget.onLinkPolicy(currentValues);
                  },
                  icon: const Icon(Icons.add_task, color: Colors.white, size: 16),
                  label: const Text('Vincular a Póliza', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_controllers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text('No se detectaron campos estructurados en este documento.', style: TextStyle(color: AppTheme.textMuted)),
          )
        else
          for (final entry in _controllers.entries)
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
        if (texto.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Texto Completo Reconocido:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: AppTheme.borderLight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              texto,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', height: 1.3),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.document == null) {
      return const Center(child: Text('Selecciona un documento o sube uno nuevo', style: TextStyle(color: AppTheme.textMuted)));
    }
    if (widget.isLoading) return const Center(child: CircularProgressIndicator());

    final doc = widget.document!;
    final tamanoKb = (doc.tamanoBytes / 1024).toStringAsFixed(1);
    final shortId = doc.id.length >= 8 ? doc.id.substring(0, 8) : doc.id;

    return SingleChildScrollView(
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
                      doc.nombreArchivo,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $shortId • MIME: ${doc.tipoMime} • Tamaño: $tamanoKb KB',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(doc.estadoExtraccion),
            ],
          ),
          const SizedBox(height: 16),
          if (doc.hasResultado)
            _buildResultContent(doc)
          else
            _buildPendingBanner(doc.estadoExtraccion),
        ],
      ),
    );
  }
}
