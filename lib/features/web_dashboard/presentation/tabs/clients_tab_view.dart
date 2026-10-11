import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/repositories/clients_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/client_form_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/client_vehicles_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/otp_whatsapp_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/clients_data_table.dart';
import 'package:sigad/shared/widgets/sigad_confirm_dialog.dart';

class ClientsTabView extends StatefulWidget {
  final ClientsRepository? clientsRepository;

  const ClientsTabView({super.key, this.clientsRepository});

  @override
  State<ClientsTabView> createState() => _ClientsTabViewState();
}

class _ClientsTabViewState extends State<ClientsTabView> {
  final _searchCtrl = TextEditingController();
  late final ClientsRepository _repository;
  Timer? _debounceTimer;

  List<ClientModel> _clients = [];
  int _total = 0;
  int _skip = 0;
  static const int _limit = 10;
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
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String? _getAuthToken() {
    try {
      final state = context.read<AuthBloc>().state;
      return state is AuthSuccess ? state.token : null;
    } catch (_) {
      return null;
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _skip = 0;
      });
      _loadClients();
    });
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _repository.getClients(
        query: _searchCtrl.text.trim(),
        skip: _skip,
        limit: _limit,
        token: _getAuthToken(),
      );
      if (!mounted) return;
      setState(() {
        _clients = res.items;
        _total = res.total;
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

  Future<void> _openClientDialog() async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => const ClientFormDialog(),
    );
    if (result == null || !mounted) return;

    if (result is CreateClientRequest) {
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
  }

  Future<void> _editClient(ClientModel client) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (_) => ClientFormDialog(initialClient: client),
    );
    if (result == null || !mounted) return;

    if (result is UpdateClientRequest) {
      try {
        final updated = await _repository.updateClient(
          client.id,
          result,
          token: _getAuthToken(),
        );
        if (!mounted) return;
        await _loadClients();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cliente ${updated.nombres} actualizado.'),
              backgroundColor: AppTheme.successColor,
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
  }

  Future<void> _deleteClient(ClientModel client) async {
    final confirmed = await showSigadConfirm(
      context,
      title: 'Eliminar Cliente',
      message: '¿Está seguro de eliminar a ${client.nombres}? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await _repository.deleteClient(client.id, token: _getAuthToken());
      if (!mounted) return;
      await _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente eliminado con éxito.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar cliente: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
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

  void _openClientVehicles(ClientModel client) {
    showDialog(
      context: context,
      builder: (_) => ClientVehiclesDialog(client: client),
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
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Buscar cliente por nombre o identificación...',
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
                      clients: _clients,
                      total: _total,
                      skip: _skip,
                      limit: _limit,
                      onPageChanged: (newSkip) {
                        setState(() {
                          _skip = newSkip;
                        });
                        _loadClients();
                      },
                      onGenerateOtp: _regenerateOtp,
                      onRegisterVehicle: _openClientVehicles,
                      onEdit: _editClient,
                      onDelete: _deleteClient,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

