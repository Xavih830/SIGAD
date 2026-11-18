import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/core/repositories/vehicles_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/plate_validator.dart';
import 'package:sigad/shared/widgets/sigad_form_dialog.dart';
import 'package:sigad/shared/widgets/sigad_text_field.dart';

class VehicleFormDialog extends StatefulWidget {
  final ClientModel client;
  final VehicleModel? initialVehicle;
  final Future<void> Function(CreateVehicleRequest request)? onSubmit;
  final VehiclesRepository? vehiclesRepository;

  const VehicleFormDialog({
    super.key,
    required this.client,
    this.initialVehicle,
    this.onSubmit,
    this.vehiclesRepository,
  });

  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _plateCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _motorCtrl;
  late final TextEditingController _chasisCtrl;
  late final TextEditingController _colorCtrl;

  PlateType? _detectedType;

  @override
  void initState() {
    super.initState();
    final v = widget.initialVehicle;
    _plateCtrl = TextEditingController(text: v?.plate ?? '');
    _brandCtrl = TextEditingController(text: v?.brand ?? '');
    _modelCtrl = TextEditingController(text: v?.model ?? '');
    _yearCtrl = TextEditingController(text: v != null ? v.year.toString() : DateTime.now().year.toString());
    _motorCtrl = TextEditingController(text: v?.motor ?? '');
    _chasisCtrl = TextEditingController(text: v?.chasis ?? '');
    _colorCtrl = TextEditingController(text: v?.color ?? '');

    _updatePlateType(_plateCtrl.text);
    _plateCtrl.addListener(() {
      _updatePlateType(_plateCtrl.text);
    });
  }

  void _updatePlateType(String text) {
    final type = classifyPlate(text.trim());
    if (type != _detectedType) {
      setState(() {
        _detectedType = type;
      });
    }
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _motorCtrl.dispose();
    _chasisCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      throw Exception('Por favor corrige los campos señalados en el formulario.');
    }

    final cleanPlate = _plateCtrl.text.trim().toUpperCase();
    final year = int.parse(_yearCtrl.text.trim());
    final clientId = widget.client.id;

    final req = CreateVehicleRequest(
      plate: cleanPlate,
      brand: _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: year,
      motor: _motorCtrl.text.trim().toUpperCase(),
      chasis: _chasisCtrl.text.trim().toUpperCase(),
      color: _colorCtrl.text.trim().toUpperCase(),
      clientId: clientId,
    );

    if (widget.onSubmit != null) {
      await widget.onSubmit!(req);
    } else {
      final repo = widget.vehiclesRepository ?? VehiclesRepository();
      await repo.createVehicle(req);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxYear = DateTime.now().year + 1;

    return SigadFormDialog(
      title: 'Registrar Vehículo',
      maxWidth: 540,
      onSubmit: _handleSave,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado de solo lectura con cliente
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cliente: ${widget.client.nombres}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Identificación: ${widget.client.identificacion}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Placa con chip en vivo
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SigadTextField(
                    controller: _plateCtrl,
                    label: 'Placa ANT',
                    hintText: 'ej. PBA-1234 o AB-123C',
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'La placa es requerida';
                      if (!isValidPlate(v)) return 'Formato inválido (ej. PBA-1234, AB-1234)';
                      return null;
                    },
                  ),
                ),
                if (_detectedType != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Chip(
                      label: Text(
                        _detectedType!.label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.blue.shade50,
                      side: BorderSide(color: Colors.blue.shade300),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Marca y Modelo
            Row(
              children: [
                Expanded(
                  child: SigadTextField(
                    controller: _brandCtrl,
                    label: 'Marca',
                    hintText: 'ej. Toyota',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SigadTextField(
                    controller: _modelCtrl,
                    label: 'Modelo',
                    hintText: 'ej. Corolla Cross',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Año y Color
            Row(
              children: [
                Expanded(
                  child: SigadTextField(
                    controller: _yearCtrl,
                    label: 'Año',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      final parsed = int.tryParse(v);
                      if (parsed == null || parsed < 1900 || parsed > maxYear) {
                        return 'Año entre 1900 y $maxYear';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SigadTextField(
                    controller: _colorCtrl,
                    label: 'Color',
                    hintText: 'ej. Blanco',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      if (v.trim().length < 3 || v.trim().length > 30) {
                        return 'Entre 3 y 30 caracteres';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Motor
            SigadTextField(
              controller: _motorCtrl,
              label: 'Número de Motor',
              hintText: 'ej. 2ZR-FE123456',
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El motor es requerido';
                final clean = v.trim().toUpperCase();
                if (!RegExp(r'^[A-Z0-9-]{5,30}$').hasMatch(clean)) {
                  return 'Debe tener entre 5 y 30 caracteres alfanuméricos o guiones';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Chasis con contador de 17 caracteres
            SigadTextField(
              controller: _chasisCtrl,
              label: 'Número de Chasis (VIN)',
              hintText: '17 caracteres (sin I, O, Q)',
              textCapitalization: TextCapitalization.characters,
              maxLength: 17,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-HJ-NPR-Za-hj-npr-z0-9]')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El chasis es requerido';
                final clean = v.trim().toUpperCase();
                if (clean.length != 17) {
                  return 'Debe tener exactamente 17 caracteres';
                }
                if (!RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(clean)) {
                  return 'Chasis VIN inválido (no se permiten I, O, Q)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
