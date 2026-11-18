import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/security/app_capability.dart';
import 'package:sigad/core/security/authorization_policy.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/shared/widgets/sigad_data_table.dart';

class ClientsDataTable extends StatefulWidget {
  final List<ClientModel> clients;
  final int? total;
  final int? skip;
  final int limit;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<ClientModel> onGenerateOtp;
  final ValueChanged<ClientModel>? onEdit;
  final ValueChanged<ClientModel>? onDelete;
  final ValueChanged<ClientModel>? onRegisterVehicle;

  const ClientsDataTable({
    super.key,
    required this.clients,
    this.total,
    this.skip,
    this.limit = 10,
    this.onPageChanged,
    required this.onGenerateOtp,
    this.onEdit,
    this.onDelete,
    this.onRegisterVehicle,
  });

  @override
  State<ClientsDataTable> createState() => _ClientsDataTableState();
}

class _ClientsDataTableState extends State<ClientsDataTable> {
  int _internalSkip = 0;

  @override
  Widget build(BuildContext context) {
    final isServerPaginated = widget.total != null && widget.onPageChanged != null;
    final totalRows = widget.total ?? widget.clients.length;
    final currentSkip = isServerPaginated ? (widget.skip ?? 0) : _internalSkip;
    final displayedClients = isServerPaginated
        ? widget.clients
        : widget.clients.skip(currentSkip).take(widget.limit).toList();

    UserModel? currentUser;
    try {
      final authState = context.watch<AuthBloc>().state;
      if (authState is AuthSuccess) {
        currentUser = authState.user;
      }
    } catch (_) {
      // In test environments without AuthBloc provider
    }

    final canEdit = widget.onEdit != null &&
        (currentUser == null || AuthorizationPolicy.canUser(currentUser, AppCapability.editClients));
    final canDelete = widget.onDelete != null &&
        (currentUser == null || AuthorizationPolicy.canUser(currentUser, AppCapability.deleteClients));

    return SigadDataTable<ClientModel>(
      emptyMessage: 'No hay clientes registrados.',
      total: totalRows,
      skip: currentSkip,
      limit: widget.limit,
      onPageChanged: (newSkip) {
        if (isServerPaginated) {
          widget.onPageChanged!(newSkip);
        } else {
          setState(() {
            _internalSkip = newSkip;
          });
        }
      },
      columns: [
        SigadColumn(
          label: const Text('Identificación', style: TextStyle(fontWeight: FontWeight.bold)),
          cellBuilder: (c) => Text(c.identificacion, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        SigadColumn(
          label: const Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold)),
          cellBuilder: (c) => Text(c.nombres),
        ),
        SigadColumn(
          label: const Text('Correo Electrónico', style: TextStyle(fontWeight: FontWeight.bold)),
          cellBuilder: (c) => Text(c.email ?? ''),
        ),
        SigadColumn(
          label: const Text('Teléfono', style: TextStyle(fontWeight: FontWeight.bold)),
          cellBuilder: (c) => Text(c.telefono ?? ''),
        ),
        SigadColumn(
          label: const Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold)),
          cellBuilder: (c) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.key, color: Colors.green, size: 20),
                tooltip: 'Generar código OTP / WhatsApp',
                onPressed: () => widget.onGenerateOtp(c),
              ),
              if (widget.onRegisterVehicle != null)
                IconButton(
                  icon: const Icon(Icons.directions_car, color: Colors.blue, size: 20),
                  tooltip: 'Vehículos del cliente',
                  onPressed: () => widget.onRegisterVehicle!(c),
                ),
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.indigo, size: 20),
                  tooltip: 'Editar cliente',
                  onPressed: () => widget.onEdit!(c),
                ),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  tooltip: 'Eliminar cliente',
                  onPressed: () => widget.onDelete!(c),
                ),
            ],
          ),
        ),
      ],
      rows: displayedClients,
    );
  }
}

