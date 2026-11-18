import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/policy_schema_model.dart';
import 'package:sigad/core/repositories/policy_schemas_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_schema_create_dialog.dart';

class PolicySchemasTabView extends StatefulWidget {
  final PolicySchemasRepository? repository;
  final String? authToken;

  const PolicySchemasTabView({
    super.key,
    this.repository,
    this.authToken,
  });

  @override
  State<PolicySchemasTabView> createState() => _PolicySchemasTabViewState();
}

class _PolicySchemasTabViewState extends State<PolicySchemasTabView> {
  late final PolicySchemasRepository _repo;
  bool _isLoadingList = false;
  bool _isLoadingDetail = false;
  bool _isActivating = false;
  String? _errorMessage;
  List<PolicySchemaListItemModel> _schemas = [];
  PolicySchemaModel? _selectedSchema;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PolicySchemasRepository();
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

  Future<void> _abrirCrearEsquema() async {
    final nuevo = await showDialog<PolicySchemaModel>(
      context: context,
      builder: (_) => PolicySchemaCreateDialog(
        repository: _repo,
        authToken: _getAuthToken(),
      ),
    );

    if (nuevo != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Esquema "${nuevo.codigo}" (v${nuevo.version}) creado exitosamente.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      await _cargarEsquemas();
      await _seleccionarEsquema(nuevo.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && _schemas.isEmpty) {
      return ErrorView(
        message: _errorMessage!,
        onRetry: _cargarEsquemas,
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.directions_car_outlined, color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Text(
                      'Gestión de Esquemas de Pólizas Vehiculares',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Actualizar lista',
                      onPressed: _isLoadingList ? null : _cargarEsquemas,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _abrirCrearEsquema,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Nuevo Esquema'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 340,
                  child: _buildListaEsquemas(),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _buildPanelDetalle(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaEsquemas() {
    if (_isLoadingList) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_schemas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No hay esquemas de pólizas registrados.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted),
          ),
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.esActivo ? 'ACTIVO' : 'INACTIVO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: item.esActivo ? AppTheme.successColor : AppTheme.textMuted,
              ),
            ),
          ),
          onTap: () => _seleccionarEsquema(item.id),
        );
      },
    );
  }

  Widget _buildPanelDetalle() {
    if (_isLoadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedSchema == null) {
      return const Center(
        child: Text(
          'Seleccione un esquema del panel izquierdo para ver sus especificaciones.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    final s = _selectedSchema!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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
                      s.nombre,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código: ${s.codigo} • Versión: ${s.version}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!s.esActivo)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                  onPressed: _isActivating ? null : _activarVersion,
                  icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                  label: const Text('Activar Esta Versión', style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (s.descripcion != null && s.descripcion!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(s.descripcion!, style: const TextStyle(fontSize: 13)),
            ),
          const SizedBox(height: 20),

          Text(
            'Campos y Atributos Personalizados (${s.campos.length}):',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          Table(
            border: TableBorder.all(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(8)),
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(padding: EdgeInsets.all(10), child: Text('Campo', style: TextStyle(fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.all(10), child: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.all(10), child: Text('Obligatorio', style: TextStyle(fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.all(10), child: Text('Formato', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
              ...s.campos.map((c) => TableRow(
                    children: [
                      Padding(padding: const EdgeInsets.all(10), child: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w500))),
                      Padding(padding: const EdgeInsets.all(10), child: Text(c.tipo.toUpperCase(), style: const TextStyle(fontSize: 12))),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          c.esObligatorio ? 'Sí' : 'No',
                          style: TextStyle(
                            color: c.esObligatorio ? Colors.red.shade700 : AppTheme.textMuted,
                            fontWeight: c.esObligatorio ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      Padding(padding: const EdgeInsets.all(10), child: Text(c.formatoFecha ?? '-', style: const TextStyle(fontSize: 12))),
                    ],
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

