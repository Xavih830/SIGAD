import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_form_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/policies_data_table.dart';

class PoliciesTabView extends StatefulWidget {
  const PoliciesTabView({super.key});

  @override
  State<PoliciesTabView> createState() => _PoliciesTabViewState();
}

class _PoliciesTabViewState extends State<PoliciesTabView> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  List<PolicyModel> _policies = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPolicies();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String? _getAuthToken() {
    final state = context.read<AuthBloc>().state;
    return state is AuthSuccess ? (state.user['token'] as String? ?? state.user['access_token'] as String?) : null;
  }

  Future<void> _loadPolicies() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/polizas'), headers: ApiConfig.authHeaders(_getAuthToken())).timeout(ApiConfig.defaultTimeout);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List).whereType<Map<String, dynamic>>().map((i) => PolicyModel.fromJson(i)).toList();
        setState(() { _policies = list; _isLoading = false; });
      } else {
        setState(() { _isLoading = false; _errorMessage = 'Error ${res.statusCode}: ${res.body}'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
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

  Future<void> _openPolicyForm([PolicyModel? existing]) async {
    List<Map<String, dynamic>> clients = [];
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/clientes'), headers: ApiConfig.authHeaders(_getAuthToken()));
      if (res.statusCode == 200) clients = (jsonDecode(res.body) as List).map((c) => Map<String, dynamic>.from(c as Map)).toList();
    } catch (_) {}

    if (!mounted) return;
    final result = await showDialog<PolicyModel>(context: context, builder: (_) => PolicyFormDialog(initialPolicy: existing, clients: clients));
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Póliza ${result.number} registrada.'), backgroundColor: AppTheme.successColor));
      await _loadPolicies();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && _policies.isEmpty) return ErrorView(message: _errorMessage!, onRetry: _loadPolicies);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.borderLight)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: TextField(controller: _searchCtrl, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Buscar póliza...', prefixIcon: Icon(Icons.search)))),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _statusFilter,
                  onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos los Estados')),
                    DropdownMenuItem(value: 'activa', child: Text('Activa')),
                    DropdownMenuItem(value: 'vencida', child: Text('Vencida')),
                    DropdownMenuItem(value: 'cancelada', child: Text('Cancelada')),
                  ],
                ),
                const SizedBox(width: 16),
                IconButton(tooltip: 'Refrescar', onPressed: _isLoading ? null : _loadPolicies, icon: const Icon(Icons.refresh)),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: () => _openPolicyForm(), icon: const Icon(Icons.add), label: const Text('Crear Póliza')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading ? const Center(child: CircularProgressIndicator()) : PoliciesDataTable(policies: _getFilteredPolicies(), onEdit: _openPolicyForm),
            ),
          ],
        ),
      ),
    );
  }
}
