import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/client_form_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/otp_whatsapp_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/clients_data_table.dart';

class ClientsTabView extends StatefulWidget {
  const ClientsTabView({super.key});

  @override
  State<ClientsTabView> createState() => _ClientsTabViewState();
}

class _ClientsTabViewState extends State<ClientsTabView> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadClients();
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

  Future<void> _loadClients() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/v1/clientes'), headers: ApiConfig.authHeaders(_getAuthToken())).timeout(ApiConfig.defaultTimeout);
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _clients = (jsonDecode(res.body) as List).map((c) => Map<String, dynamic>.from(c as Map)).toList();
          _isLoading = false;
        });
      } else {
        setState(() { _isLoading = false; _errorMessage = 'Error ${res.statusCode}: ${res.body}'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  List<Map<String, dynamic>> _filteredClients() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _clients;
    return _clients.where((c) {
      final name = (c['nombres'] ?? c['name'] ?? '').toString().toLowerCase();
      final id = (c['identificacion'] ?? c['id'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || id.contains(q) || email.contains(q);
    }).toList();
  }

  Future<void> _openClientDialog() async {
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const ClientFormDialog());
    if (result == null || !mounted) return;
    try {
      final payload = {'identificacion': result['id'], 'nombres': result['name'], 'email': result['email'], 'telefono': result['phone']};
      final res = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/clientes'), headers: ApiConfig.authHeaders(_getAuthToken()), body: jsonEncode(payload)).timeout(ApiConfig.defaultTimeout);
      if (!mounted) return;
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        await _loadClients();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cliente ${data['nombres']} registrado.'), backgroundColor: AppTheme.successColor));
          final otp = data['codigo_vinculacion']?.toString();
          if (otp != null && otp.isNotEmpty) _showOtpDialog(data, otp);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res.body}'), backgroundColor: AppTheme.errorColor));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
    }
  }

  Future<void> _regenerateOtp(Map<String, dynamic> client) async {
    final id = client['id']?.toString();
    if (id == null) return;
    try {
      final res = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/v1/clientes/$id/otp'), headers: ApiConfig.authHeaders(_getAuthToken())).timeout(ApiConfig.defaultTimeout);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _showOtpDialog(data, data['codigo_vinculacion']?.toString() ?? '');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al generar código OTP.'), backgroundColor: AppTheme.errorColor));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
    }
  }

  void _showOtpDialog(Map<String, dynamic> c, String otp) {
    showDialog(
      context: context,
      builder: (_) => OtpWhatsAppDialog(
        clientName: c['nombres']?.toString() ?? c['name']?.toString() ?? 'Cliente',
        clientId: c['identificacion']?.toString() ?? c['id']?.toString() ?? '',
        clientEmail: c['email']?.toString(),
        otpCode: otp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && _clients.isEmpty) return ErrorView(message: _errorMessage!, onRetry: _loadClients);
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
                Expanded(child: TextField(controller: _searchCtrl, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Buscar cliente...', prefixIcon: Icon(Icons.search)))),
                const SizedBox(width: 16),
                IconButton(tooltip: 'Refrescar', onPressed: _isLoading ? null : _loadClients, icon: const Icon(Icons.refresh)),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: _openClientDialog, icon: const Icon(Icons.person_add), label: const Text('Nuevo Cliente')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading ? const Center(child: CircularProgressIndicator()) : ClientsDataTable(clients: _filteredClients(), onGenerateOtp: _regenerateOtp),
            ),
          ],
        ),
      ),
    );
  }
}
