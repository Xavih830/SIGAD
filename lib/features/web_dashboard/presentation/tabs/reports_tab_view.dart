import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/repositories/policies_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/print/print_helper.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';

class ReportsTabView extends StatefulWidget {
  final PoliciesRepository? policiesRepository;

  const ReportsTabView({super.key, this.policiesRepository});

  @override
  State<ReportsTabView> createState() => _ReportsTabViewState();
}

class _ReportsTabViewState extends State<ReportsTabView> {
  late final PoliciesRepository _policiesRepo;
  List<PolicyModel> _policies = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _policiesRepo = widget.policiesRepository ?? PoliciesRepository();
    _loadPolicies();
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
      final list = await _policiesRepo.getPolicies(token: _getAuthToken());
      if (!mounted) return;
      setState(() {
        _policies = list;
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

  void _printReport() {
    if (kIsWeb) {
      triggerPrint();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La exportación por impresión solo está disponible en entorno Web.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _policies.isEmpty) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.errorColor)));
    }

    final totalCount = _policies.length;
    final activeCount = _policies.where((p) => p.status.toLowerCase() == 'activa' && !p.isExpired).length;
    final expiredCount = _policies.where((p) => p.isExpired).length;
    final canceledCount = _policies.where((p) => p.status.toLowerCase() == 'cancelada').length;
    final totalInsured = _policies.fold<double>(0.0, (acc, p) => acc + p.insuredValue);
    final totalPremiums = _policies.fold<double>(0.0, (acc, p) => acc + p.monthlyPremium);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Métricas Generales de Cartera', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar métricas',
                      onPressed: _isLoading ? null : _loadPolicies,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _printReport,
                      icon: const Icon(Icons.print),
                      label: const Text('Exportar / Imprimir'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _kpi('Total Pólizas', totalCount.toString(), Icons.folder_shared, Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: _kpi('Pólizas Activas', activeCount.toString(), Icons.verified, Colors.green)),
                const SizedBox(width: 16),
                Expanded(child: _kpi('Capital Asegurado', '\$${totalInsured.toStringAsFixed(2)}', Icons.shield, Colors.deepPurple)),
                const SizedBox(width: 16),
                Expanded(child: _kpi('Primas Mensuales', '\$${totalPremiums.toStringAsFixed(2)}', Icons.monetization_on, Colors.teal)),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Desglose por Estado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: const Text('Pólizas Vigentes'),
                    trailing: Text('$activeCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const Divider(color: AppTheme.borderLight),
                  ListTile(
                    leading: const Icon(Icons.warning, color: Colors.orange),
                    title: const Text('Pólizas Vencidas'),
                    trailing: Text('$expiredCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const Divider(color: AppTheme.borderLight),
                  ListTile(
                    leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                    title: const Text('Pólizas Canceladas'),
                    trailing: Text('$canceledCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String val, IconData icon, Color col) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: col.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: col, size: 28),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: col)),
        ],
      ),
    );
  }
}
