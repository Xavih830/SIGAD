import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/repositories/clients_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/client_form_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/otp_whatsapp_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/clients_data_table.dart';

class ClientsTabView extends StatefulWidget {
  final ClientsRepository? clientsRepository;

  const ClientsTabView({super.key, this.clientsRepository});

  @override
  State<ClientsTabView> createState() => _ClientsTabViewState();
}

class _ClientsTabViewState extends State<ClientsTabView> {
  final _searchCtrl = TextEditingController();
  late final ClientsRepository _repository;
  List<ClientModel> _clients = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.clientsRepository ?? ClientsRepository();
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final clients = await _repository.getClients(token: _getAuthToken());
      if (!mounted) return;
      setState(() {
        _clients = clients;
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

  List<ClientModel> _filteredClients() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _clients;
    return _clients.where((c) {
      final name = c.nombres.toLowerCase();
      final id = c.identificacion.toLowerCase();
      final email = (c.email ?? '').toLowerCase();
      return name.contains(q) || id.contains(q) || email.contains(q);
    }).toList();
  }

  Future<void> _openClientDialog() async {
    final result = await showDialog<CreateClientRequest>(
      context: context,
      builder: (_) => const ClientFormDialog(),
    );
    if (result == null || !mounted) return;

    try {
      final created = await _repository.createClient(result, token: _getAuthToken());
      if (!mounted) return;
      await _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente ${created.nombres} registrado.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        final otp = created.codigoVinculacion;
        if (otp != null && otp.isNotEmpty) {
          _showOtpDialog(created, otp);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _regenerateOtp(ClientModel client) async {
    try {
      final updated = await _repository.requestOtp(client.id, token: _getAuthToken());
      if (!mounted) return;
      final otp = updated.codigoVinculacion;
      if (otp != null && otp.isNotEmpty) {
        _showOtpDialog(updated, otp);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al generar código OTP.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showOtpDialog(ClientModel c, String otp) {
    showDialog(
      context: context,
      builder: (_) => OtpWhatsAppDialog(
        clientName: c.nombres,
        clientId: c.identificacion,
        clientEmail: c.email,
        otpCode: otp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && _clients.isEmpty) {
      return ErrorView(message: _errorMessage!, onRetry: _loadClients);
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
                      hintText: 'Buscar cliente...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Refrescar',
                  onPressed: _isLoading ? null : _loadClients,
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _openClientDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Nuevo Cliente'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ClientsDataTable(
                      clients: _filteredClients(),
                      onGenerateOtp: _regenerateOtp,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
