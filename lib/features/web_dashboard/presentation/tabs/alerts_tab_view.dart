import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/repositories/policies_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';

class AlertsTabView extends StatefulWidget {
  final PoliciesRepository? policiesRepository;

  const AlertsTabView({super.key, this.policiesRepository});

  @override
  State<AlertsTabView> createState() => _AlertsTabViewState();
}

class _AlertsTabViewState extends State<AlertsTabView> {
  late final PoliciesRepository _policiesRepo;
  int _thresholdDays = 30;
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

  List<PolicyModel> _getExpiringPolicies() {
    return _policies.where((p) {
      return !p.isExpired && p.daysUntilExpiration <= _thresholdDays && p.daysUntilExpiration >= 0;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final expiring = _getExpiringPolicies();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pólizas Próximas a Vencer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('Umbral: ', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                    DropdownButton<int>(
                      value: _thresholdDays,
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 días')),
                        DropdownMenuItem(value: 30, child: Text('30 días')),
                        DropdownMenuItem(value: 60, child: Text('60 días')),
                        DropdownMenuItem(value: 90, child: Text('90 días')),
                      ],
                      onChanged: (v) => setState(() => _thresholdDays = v ?? 30),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar',
                      onPressed: _isLoading ? null : _loadPolicies,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.errorColor)))
                      : expiring.isEmpty
                          ? Center(
                              child: Text(
                                'No hay pólizas por vencer en los próximos $_thresholdDays días.',
                                style: const TextStyle(color: AppTheme.textMuted),
                              ),
                            )
                          : ListView.builder(
                              itemCount: expiring.length,
                              itemBuilder: (ctx, i) {
                                final p = expiring[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningColor.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
                                    ),
                                    title: Text(
                                      p.vehicle != null
                                          ? '${p.number} - ${p.vehicle!.brand} ${p.vehicle!.model} (${p.vehicle!.plate})'
                                          : '${p.number} - Sin vehículo asignado',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      'Vence el: ${p.endDate.toIso8601String().substring(0, 10)}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Quedan ${p.daysUntilExpiration} días',
                                        style: TextStyle(
                                          color: Colors.orange.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
