import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/mobile_client/presentation/pages/policy_detail_page.dart';

class MobilePoliciesTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onNavigateToContact;

  const MobilePoliciesTab({super.key, required this.user, required this.onNavigateToContact});

  @override
  State<MobilePoliciesTab> createState() => _MobilePoliciesTabState();
}

class _MobilePoliciesTabState extends State<MobilePoliciesTab> {
  List<PolicyModel> _policies = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPolicies();
  }

  Future<void> _loadPolicies() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final token = widget.user['access_token'] as String?;
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/polizas'),
        headers: ApiConfig.authHeaders(token),
      ).timeout(ApiConfig.defaultTimeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        final parsed = list.whereType<Map<String, dynamic>>().map((i) => PolicyModel.fromJson(i)).toList();
        parsed.sort((a, b) => (!b.isExpired ? 1 : 0).compareTo(!a.isExpired ? 1 : 0));
        setState(() { _policies = parsed; _isLoading = false; });
      } else {
        setState(() { _errorMessage = 'Error ${response.statusCode}: No se pudieron cargar las pólizas'; _isLoading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = 'No se pudo conectar con el servidor. Verifica tu conexión.'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return ErrorView(message: _errorMessage!, onRetry: _loadPolicies);

    final activeCount = _policies.where((p) => !p.isExpired).length;

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
              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hola, ${widget.user['name'] ?? 'Cliente'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Tienes $activeCount póliza(s) vehicular(es) activa(s).', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9))),
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
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PolicyDetailPage(policy: p, onReportError: widget.onNavigateToContact))),
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
                    decoration: BoxDecoration(color: isExp ? AppTheme.errorColor.withOpacity(0.1) : AppTheme.successColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(isExp ? 'Vencida' : 'Activa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isExp ? AppTheme.errorColor : AppTheme.successColor)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(veh != null ? '${veh.brand} ${veh.model} (${veh.year})' : 'Vehículo', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textDark)),
              const SizedBox(height: 4),
              Text('Placa: ${veh?.plate ?? 'S/P'}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              const Divider(height: 20, color: AppTheme.borderLight),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Vence: ${p.endDate.toIso8601String().substring(0, 10)}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
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
