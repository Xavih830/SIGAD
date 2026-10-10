import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/repositories/clients_repository.dart';
import 'package:sigad/core/repositories/policies_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_detail_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_form_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/policies_data_table.dart';

class PoliciesTabView extends StatefulWidget {
  final PoliciesRepository? policiesRepository;
  final ClientsRepository? clientsRepository;

  const PoliciesTabView({
    super.key,
    this.policiesRepository,
    this.clientsRepository,
  });

  @override
  State<PoliciesTabView> createState() => _PoliciesTabViewState();
}

class _PoliciesTabViewState extends State<PoliciesTabView> {
  final _searchCtrl = TextEditingController();
  late final PoliciesRepository _policiesRepo;
  late final ClientsRepository _clientsRepo;
  String _statusFilter = 'all';
  List<PolicyModel> _policies = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _policiesRepo = widget.policiesRepository ?? PoliciesRepository();
    _clientsRepo = widget.clientsRepository ?? ClientsRepository();
    _loadPolicies();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String? _getAuthToken() {
    final state = context.read<AuthBloc>().state;
    return state is AuthSuccess ? state.token : null;
  }

  Future<void> _loadPolicies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final policies = await _policiesRepo.getPolicies(token: _getAuthToken());
      if (!mounted) return;
      setState(() {
        _policies = policies;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  List<PolicyModel> _getFilteredPolicies() {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _policies.where((p) {
      final matchesQuery = query.isEmpty ||
          p.number.toLowerCase().contains(query) ||
          (p.vehicle?.plate.toLowerCase().contains(query) ?? false) ||
          (p.clientName?.toLowerCase().contains(query) ?? false) ||
          p.clientId.toLowerCase().contains(query);
      final matchesStatus = _statusFilter == 'all' || p.status.toLowerCase() == _statusFilter;
      return matchesQuery && matchesStatus;
    }).toList();
  }

  Future<void> _openPolicyForm() async {
    try {
      final clients = await _clientsRepo.getClients(token: _getAuthToken());
      if (!mounted) return;
      final result = await showDialog<CreatePolicyRequest>(
        context: context,
        builder: (_) => PolicyFormDialog(clients: clients, authToken: _getAuthToken()),
      );
      if (result != null && mounted) {
        await _policiesRepo.createPolicy(result, token: _getAuthToken());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Póliza ${result.number} registrada con éxito.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        await _loadPolicies();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en emisión de póliza: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _showPolicyDetail(PolicyModel policy) async {
    await showDialog(
      context: context,
      builder: (_) => PolicyDetailDialog(
        policy: policy,
        onStatusChange: (nuevoEstado) async {
          try {
            await _policiesRepo.updatePolicyStatus(
              policy.id,
              nuevoEstado,
              token: _getAuthToken(),
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Estado de póliza ${policy.number} actualizado a $nuevoEstado.'),
                backgroundColor: AppTheme.successColor,
              ),
            );
            await _loadPolicies();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al actualizar estado: $e'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && _policies.isEmpty) {
      return ErrorView(message: _errorMessage!, onRetry: _loadPolicies);
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Buscar póliza...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _statusFilter,
                  onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos los Estados')),
                    DropdownMenuItem(value: 'activa', child: Text('Activa')),
                    DropdownMenuItem(value: 'por_vencer', child: Text('Por Vencer')),
                    DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                    DropdownMenuItem(value: 'vencida', child: Text('Vencida')),
                    DropdownMenuItem(value: 'cancelada', child: Text('Cancelada')),
                  ],
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Refrescar',
                  onPressed: _isLoading ? null : _loadPolicies,
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _openPolicyForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Póliza'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : PoliciesDataTable(
                      policies: _getFilteredPolicies(),
                      onViewDetail: _showPolicyDetail,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
