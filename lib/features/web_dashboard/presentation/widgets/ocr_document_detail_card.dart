import 'package:flutter/material.dart';
import 'package:sigad/core/models/document_model.dart';
import 'package:sigad/core/models/extraction_schema_model.dart';
import 'package:sigad/core/repositories/documents_repository.dart';
import 'package:sigad/core/repositories/extraction_schemas_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/file_downloader_helper.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/ocr/ocr_editable_fields_list.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/ocr/ocr_raw_text_preview.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/ocr/ocr_schema_reextraction_bar.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/ocr/ocr_status_badge.dart';

class OcrDocumentDetailCard extends StatefulWidget {
  final DocumentModel? document;
  final bool isLoading;
  final VoidCallback onRefresh;
  final Function(Map<String, dynamic> confirmedFields) onLinkPolicy;
  final String? authToken;
  final DocumentsRepository? documentsRepository;
  final ExtractionSchemasRepository? extractionSchemasRepository;

  const OcrDocumentDetailCard({
    super.key,
    required this.document,
    required this.isLoading,
    required this.onRefresh,
    required this.onLinkPolicy,
    this.authToken,
    this.documentsRepository,
    this.extractionSchemasRepository,
  });

  @override
  State<OcrDocumentDetailCard> createState() => _OcrDocumentDetailCardState();
}

class _OcrDocumentDetailCardState extends State<OcrDocumentDetailCard> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;
  bool _isDownloading = false;
  bool _isReExtracting = false;

  late final ExtractionSchemasRepository _extractionSchemasRepo;
  List<ExtractionSchemaListItemModel> _extractionSchemas = [];
  String? _selectedExtractionSchemaId;

  @override
  void initState() {
    super.initState();
    _extractionSchemasRepo = widget.extractionSchemasRepository ?? ExtractionSchemasRepository();
    _initControllers();
    _loadExtractionSchemas();
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

  Future<void> _loadExtractionSchemas() async {
    try {
      final list = await _extractionSchemasRepo.getSchemas(token: widget.authToken);
      if (!mounted) return;
      setState(() {
        _extractionSchemas = list;
        final activo = list.where((s) => s.esActivo).firstOrNull;
        _selectedExtractionSchemaId = activo?.id ?? (list.isNotEmpty ? list.first.id : null);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar esquemas de extracción: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _reprocesarConEsquema() async {
    if (widget.document == null || _selectedExtractionSchemaId == null) return;
    final doc = widget.document!;

    ExtractionSchemaListItemModel? selectedSchema;
    for (final s in _extractionSchemas) {
      if (s.id == _selectedExtractionSchemaId) {
        selectedSchema = s;
        break;
      }
    }

    final schemaName = selectedSchema != null
        ? '${selectedSchema.nombre} (${selectedSchema.codigo} v${selectedSchema.version})'
        : 'el esquema seleccionado';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
            SizedBox(width: 8),
            Text('Confirmar Re-extracción'),
          ],
        ),
        content: Text(
          '¿Está seguro de re-extraer el documento "${doc.nombreArchivo}" con $schemaName?\n\n'
          'Advertencia: Si el esquema o versión actual difiere del utilizado originalmente, '
          'esta acción aplicará las nuevas reglas y sobrescribirá los campos en pantalla, '
          'pudiendo alterar datos previamente auditados o corregidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar y Re-extraer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isReExtracting = true);
    try {
      final repo = widget.documentsRepository ?? DocumentsRepository();
      final bytes = await repo.downloadDocumentBytes(
        doc.id,
        token: widget.authToken,
      );

      final result = await _extractionSchemasRepo.testSchema(
        _selectedExtractionSchemaId!,
        bytes: bytes,
        filename: doc.nombreArchivo,
        token: widget.authToken,
      );

      if (!mounted) return;
      setState(() {
        for (final c in _controllers.values) {
          c.dispose();
        }
        _controllers.clear();
        for (final entry in result.camposExtraidos.entries) {
          _controllers[entry.key] = TextEditingController(text: entry.value?.toString() ?? '');
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Documento re-procesado con éxito (Confianza: ${result.confianza.toStringAsFixed(1)}%).'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al re-procesar documento: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReExtracting = false);
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

  Future<void> _descargarDocumento() async {
    if (widget.document == null) return;
    final doc = widget.document!;

    setState(() => _isDownloading = true);
    try {
      final repo = widget.documentsRepository ?? DocumentsRepository();
      final bytes = await repo.downloadDocumentBytes(
        doc.id,
        token: widget.authToken,
      );
      FileDownloaderHelper.download(
        bytes: bytes,
        filename: doc.nombreArchivo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Documento "${doc.nombreArchivo}" descargado con éxito.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar documento: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
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
            OcrConfidenceBadge(confianza: confianza),
          ],
        ),
        const Divider(height: 24, color: AppTheme.borderLight),
        OcrSchemaReextractionBar(
          extractionSchemas: _extractionSchemas,
          selectedSchemaId: _selectedExtractionSchemaId,
          isReExtracting: _isReExtracting,
          onSchemaChanged: (id) => setState(() => _selectedExtractionSchemaId = id),
          onReExtract: _reprocesarConEsquema,
        ),
        OcrEditableFieldsList(
          controllers: _controllers,
          isSaving: _isSaving,
          onSaveRevision: _guardarRevision,
          onLinkPolicy: () {
            final currentValues = <String, dynamic>{};
            _controllers.forEach((k, v) => currentValues[k] = v.text.trim());
            widget.onLinkPolicy(currentValues);
          },
        ),
        OcrRawTextPreview(text: texto),
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
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isDownloading ? null : _descargarDocumento,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download, size: 16),
                    label: const Text('Descargar Documento'),
                  ),
                  OcrStatusBadge(estado: doc.estadoExtraccion),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (doc.hasResultado)
            _buildResultContent(doc)
          else
            OcrPendingBanner(estado: doc.estadoExtraccion, onRefresh: widget.onRefresh),
        ],
      ),
    );
  }
}
