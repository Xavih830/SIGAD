import 'package:flutter/material.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/core/repositories/vehicles_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/plate_validator.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/vehicle_form_dialog.dart';
import 'package:sigad/shared/widgets/sigad_data_table.dart';

class ClientVehiclesDialog extends StatefulWidget {
  final ClientModel client;
  final VehiclesRepository? vehiclesRepository;

  const ClientVehiclesDialog({
    super.key,
    required this.client,
    this.vehiclesRepository,
  });

  @override
  State<ClientVehiclesDialog> createState() => _ClientVehiclesDialogState();
}

class _ClientVehiclesDialogState extends State<ClientVehiclesDialog> {
  late final VehiclesRepository _vehiclesRepo;
  bool _isLoading = true;
  String? _errorMessage;
  List<VehicleModel> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _vehiclesRepo = widget.vehiclesRepository ?? VehiclesRepository();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final clientId = widget.client.id;
      if (clientId.isEmpty) {
        throw Exception('El cliente no cuenta con identificador válido.');
      }
      final result = await _vehiclesRepo.getVehiclesByClient(clientId);
      if (mounted) {
        setState(() {
          _vehicles = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openRegisterVehicleDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => VehicleFormDialog(
        client: widget.client,
        vehiclesRepository: _vehiclesRepo,
      ),
    );

    if (created == true && mounted) {
      await _loadVehicles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehículos — ${widget.client.nombres}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Identificación: ${widget.client.identificacion}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openRegisterVehicleDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Registrar vehículo'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadVehicles,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Table
              Expanded(
                child: SigadDataTable<VehicleModel>(
                  isLoading: _isLoading,
                  emptyMessage: 'No hay vehículos registrados para este cliente.',
                  columns: [
                    SigadColumn<VehicleModel>(
                      label: const Text('Placa'),
                      cellBuilder: (v) => Text(
                        v.plate,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SigadColumn<VehicleModel>(
                      label: const Text('Tipo'),
                      cellBuilder: (v) {
                        final tipo = classifyPlate(v.plate)?.label ?? v.type ?? '-';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            tipo,
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                          ),
                        );
                      },
                    ),
                    SigadColumn<VehicleModel>(
                      label: const Text('Marca / Modelo'),
                      cellBuilder: (v) => Text('${v.brand} ${v.model}'),
                    ),
                    SigadColumn<VehicleModel>(
                      label: const Text('Año'),
                      cellBuilder: (v) => Text(v.year.toString()),
                      numeric: true,
                    ),
                    SigadColumn<VehicleModel>(
                      label: const Text('Color'),
                      cellBuilder: (v) => Text(v.color ?? '-'),
                    ),
                  ],
                  rows: _vehicles,
                ),
              ),
              const SizedBox(height: 16),

              // Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
