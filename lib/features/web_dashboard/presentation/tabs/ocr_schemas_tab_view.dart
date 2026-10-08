import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/extraction_schema_model.dart';
import 'package:sigad/core/repositories/extraction_schemas_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/schema_test_dialog.dart';

/// Pestaña del panel administrativo para gestión y activación de esquemas OCR dinámicos.
class OcrSchemasTabView extends StatefulWidget {
  final ExtractionSchemasRepository? repository;

  const OcrSchemasTabView({super.key, this.repository});

  @override
  State<OcrSchemasTabView> createState() => _OcrSchemasTabViewState();
}

class _OcrSchemasTabViewState extends State<OcrSchemasTabView> {
  late final ExtractionSchemasRepository _repo;
  bool _isLoadingList = false;
  bool _isLoadingDetail = false;
  bool _isActivating = false;
  String? _errorMessage;
  List<ExtractionSchemaListItemModel> _schemas = [];
  ExtractionSchemaModel? _selectedSchema;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ExtractionSchemasRepository();
    _cargarEsquemas();
  }

  String? _getAuthToken() {
    try {
      final state = context.read<AuthBloc>().state;
      return state is AuthSuccess ? state.token : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cargarEsquemas() async {
    setState(() {
      _isLoadingList = true;
      _errorMessage = null;
    });
    try {
      final list = await _repo.getSchemas(token: _getAuthToken());
      if (!mounted) return;
      setState(() {
        _schemas = list;
        _isLoadingList = false;
      });
      if (_schemas.isNotEmpty && _selectedSchema == null) {
        await _seleccionarEsquema(_schemas.first.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingList = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _seleccionarEsquema(String id) async {
    setState(() => _isLoadingDetail = true);
    try {
      final detail = await _repo.getSchemaById(id, token: _getAuthToken());
      if (mounted) {
        setState(() {
          _selectedSchema = detail;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar detalle del esquema: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  Future<void> _activarVersion() async {
    if (_selectedSchema == null || _selectedSchema!.esActivo) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Activación de Versión'),
        content: Text(
          '¿Desea activar la versión ${_selectedSchema!.version} del esquema "${_selectedSchema!.codigo}"? '
          'Las demás versiones de este código quedarán automáticamente inactivas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Activar Versión', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActivating = true);
    try {
      final updated = await _repo.activateSchema(_selectedSchema!.id, token: _getAuthToken());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Versión ${updated.version} de ${updated.codigo} activada con éxito.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        setState(() => _selectedSchema = updated);
        await _cargarEsquemas();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al activar versión: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  void _abrirDialogoPrueba() {
    if (_selectedSchema == null) return;
    showDialog(
      context: context,
      builder: (_) => SchemaTestDialog(
        schema: _selectedSchema!,
        repository: _repo,
        authToken: _getAuthToken(),
      ),
    );
  }

  Widget _buildListPanel() {
    if (_isLoadingList) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_schemas.isEmpty) {
      return const Center(
        child: Text(
          'No existen esquemas de extracción registrados.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    return ListView.separated(
      itemCount: _schemas.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _schemas[index];
        final isSelected = _selectedSchema?.id == item.id;

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
          onTap: () => _seleccionarEsquema(item.id),
        );
      },
    );
  }

  Widget _buildDetailPanel() {
    if (_isLoadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }

    final schema = _selectedSchema;
    if (schema == null) {
      return const Center(
        child: Text(
          'Selecciona un esquema para ver sus reglas y campos.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

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
                      schema.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código: ${schema.codigo} • Versión: ${schema.version}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    if (schema.descripcion != null && schema.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        schema.descripcion!,
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
                    onPressed: _abrirDialogoPrueba,
                    icon: const Icon(Icons.science_outlined, size: 16),
                    label: const Text('Probar con Documento'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: schema.esActivo ? Colors.grey : AppTheme.successColor,
                    ),
                    onPressed: (schema.esActivo || _isActivating) ? null : _activarVersion,
                    icon: _isActivating
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                    label: Text(
                      schema.esActivo ? 'Versión Activa' : 'Activar Versión',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 32),
          Text(
            'Campos y Reglas Regex (${schema.campos.length}):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (schema.campos.isEmpty)
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
                for (final c in schema.campos)
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

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return ErrorView(message: _errorMessage!, onRetry: _cargarEsquemas);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 850;

        if (!isWide) {
          return Column(
            children: [
              Expanded(flex: 2, child: _buildListPanel()),
              const Divider(height: 1),
              Expanded(flex: 3, child: _buildDetailPanel()),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(
              width: 320,
              child: Card(
                margin: const EdgeInsets.all(8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppTheme.borderLight),
                ),
                child: _buildListPanel(),
              ),
            ),
            Expanded(
              child: Card(
                margin: const EdgeInsets.all(8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppTheme.borderLight),
                ),
                child: _buildDetailPanel(),
              ),
            ),
          ],
        );
      },
    );
  }
}
