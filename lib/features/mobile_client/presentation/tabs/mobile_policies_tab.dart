import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/repositories/policies_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/date_formatter.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/mobile_client/presentation/pages/policy_detail_page.dart';

class MobilePoliciesTab extends StatefulWidget {
  final UserModel user;
  final VoidCallback onNavigateToContact;
  final PoliciesRepository? policiesRepository;

  const MobilePoliciesTab({
    super.key,
    required this.user,
    required this.onNavigateToContact,
    this.policiesRepository,
  });

  @override
  State<MobilePoliciesTab> createState() => _MobilePoliciesTabState();
}

class _MobilePoliciesTabState extends State<MobilePoliciesTab> {
  late final PoliciesRepository _policiesRepo;
  List<PolicyModel> _policies = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _policiesRepo = widget.policiesRepository ?? PoliciesRepository();
    _loadPolicies();
  }

  Future<void> _loadPolicies() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final token = widget.user.accessToken;
      final parsed = await _policiesRepo.getPolicies(token: token);
      if (!mounted) return;

      final sorted = PolicyModel.sortByActivePriority(parsed);
      setState(() { _policies = sorted; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return ErrorView(message: _errorMessage!, onRetry: _loadPolicies);

    final activeCount = PolicyModel.countActivePolicies(_policies);

    return RefreshIndicator(
      onRefresh: _loadPolicies,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hola, ${widget.user.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Tienes $activeCount póliza(s) vehicular(es) activa(s).', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_policies.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 48.0), child: Center(child: Text('No tienes pólizas registradas.', style: TextStyle(color: AppTheme.textMuted, fontSize: 16))))
          else
            ..._policies.map((p) => _buildPolicyCard(p)),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(PolicyModel p) {
    final veh = p.vehicle;
    final isExp = p.isExpired;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PolicyDetailPage(
            policy: p,
            onReportError: widget.onNavigateToContact,
            authToken: widget.user.accessToken,
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(p.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: isExp ? AppTheme.errorColor.withValues(alpha: 0.1) : AppTheme.successColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(isExp ? 'Vencida' : 'Activa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isExp ? AppTheme.errorColor : AppTheme.successColor)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(veh != null ? '${veh.brand} ${veh.model} (${veh.year})' : 'Vehículo', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textDark)),
              const SizedBox(height: 4),
              Text(veh != null ? 'Placa: ${veh.plate}' : 'Sin vehículo asignado', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              const Divider(height: 20, color: AppTheme.borderLight),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Vence: ${DateFormatter.toIsoDate(p.endDate)}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  Text('\$${p.monthlyPremium.toStringAsFixed(2)} /mes', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
                ],
              ),
              if (p.isExpiringSoon) ...[
                const SizedBox(height: 8),
                Text('⚠️ Vence en ${p.daysUntilExpiration} días', style: const TextStyle(color: AppTheme.warningColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
