import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/extraction_schema_model.dart';
import 'package:sigad/core/repositories/extraction_schemas_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/schema_test_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/ocr/ocr_schema_detail_panel.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/ocr/ocr_schemas_list_panel.dart';

class OcrSchemasTabView extends StatefulWidget {
  final ExtractionSchemasRepository? repository;
  final String? authToken;

  const OcrSchemasTabView({
    super.key,
    this.repository,
    this.authToken,
  });

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
    if (widget.authToken != null) return widget.authToken;
    final state = context.read<AuthBloc>().state;
    return state is AuthSuccess ? state.token : null;
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
              Expanded(
                flex: 2,
                child: OcrSchemasListPanel(
                  isLoading: _isLoadingList,
                  schemas: _schemas,
                  selectedSchemaId: _selectedSchema?.id,
                  onSelectSchema: _seleccionarEsquema,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                flex: 3,
                child: OcrSchemaDetailPanel(
                  isLoading: _isLoadingDetail,
                  schema: _selectedSchema,
                  isActivating: _isActivating,
                  onTestSchema: _abrirDialogoPrueba,
                  onActivateVersion: _activarVersion,
                ),
              ),
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
                child: OcrSchemasListPanel(
                  isLoading: _isLoadingList,
                  schemas: _schemas,
                  selectedSchemaId: _selectedSchema?.id,
                  onSelectSchema: _seleccionarEsquema,
                ),
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
                child: OcrSchemaDetailPanel(
                  isLoading: _isLoadingDetail,
                  schema: _selectedSchema,
                  isActivating: _isActivating,
                  onTestSchema: _abrirDialogoPrueba,
                  onActivateVersion: _activarVersion,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
