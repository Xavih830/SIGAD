import 'package:flutter/material.dart';
import 'package:sigad/core/constants/app_constants.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/core/utils/plate_validator.dart';

class PolicyFormDialog extends StatefulWidget {
  final PolicyModel? initialPolicy;
  final CreatePolicyRequest? initialRequest;
  final List<ClientModel> clients;

  const PolicyFormDialog({
    super.key,
    this.initialPolicy,
    this.initialRequest,
    required this.clients,
  });

  @override
  State<PolicyFormDialog> createState() => _PolicyFormDialogState();
}

class _PolicyFormDialogState extends State<PolicyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numCtrl, _brandCtrl, _modelCtrl, _yearCtrl, _plateCtrl, _valCtrl, _primaCtrl, _startCtrl, _endCtrl, _kmCtrl;
  late String _selectedClientDoc, _status;
  final List<String> _selectedCoverages = [];

  final List<String> _allCoverages = const [
    'Pérdida Total por Accidente', 'Pérdida Total por Robo', 'Daños Parciales al Vehículo',
    'Responsabilidad Civil', 'Asistencia Mecánica 24/7', 'Auto Sustituto (hasta 15 días)',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialPolicy;
    final req = widget.initialRequest;
    final number = p?.number ?? req?.number ?? '';
    final brand = p?.vehicle?.brand ?? req?.vehicle?.brand ?? '';
    final model = p?.vehicle?.model ?? req?.vehicle?.model ?? '';
    final year = p?.vehicle?.year.toString() ?? req?.vehicle?.year.toString() ?? '';
    final plate = p?.vehicle?.plate ?? req?.vehicle?.plate ?? '';
    final val = (p != null && p.insuredValue > 0)
        ? p.insuredValue.toStringAsFixed(2)
        : (req != null && req.insuredValue > 0 ? req.insuredValue.toStringAsFixed(2) : '');
    final prima = (p != null && p.monthlyPremium > 0)
        ? p.monthlyPremium.toStringAsFixed(2)
        : (req != null && req.monthlyPremium > 0 ? req.monthlyPremium.toStringAsFixed(2) : '');
    final km = (p != null && p.emissionMileage > 0)
        ? p.emissionMileage.toString()
        : (req != null && req.emissionMileage > 0 ? req.emissionMileage.toString() : '');
    final startDt = p?.startDate ?? req?.startDate ?? DateTime.now();
    final endDt = p?.endDate ?? req?.endDate ?? DateTime.now().add(const Duration(days: AppConstants.defaultPolicyDurationDays));

    _numCtrl = TextEditingController(text: number);
    _brandCtrl = TextEditingController(text: brand);
    _modelCtrl = TextEditingController(text: model);
    _yearCtrl = TextEditingController(text: year);
    _plateCtrl = TextEditingController(text: plate);
    _valCtrl = TextEditingController(text: val);
    _primaCtrl = TextEditingController(text: prima);
    _kmCtrl = TextEditingController(text: km);
    _startCtrl = TextEditingController(text: startDt.toIso8601String().substring(0, 10));
    _endCtrl = TextEditingController(text: endDt.toIso8601String().substring(0, 10));

    _status = p?.status ?? req?.status ?? 'activa';
    _selectedClientDoc = p?.clientId ?? req?.clientId ?? (widget.clients.isNotEmpty ? widget.clients.first.id : '');
    if (p != null) {
      _selectedCoverages.addAll(p.coverages.map((c) => c.nombre));
    } else if (req != null && req.coverages.isNotEmpty) {
      _selectedCoverages.addAll(req.coverages);
    } else {
      _selectedCoverages.add('Responsabilidad Civil');
    }
  }

  @override
  void dispose() {
    for (final c in [_numCtrl, _brandCtrl, _modelCtrl, _yearCtrl, _plateCtrl, _valCtrl, _primaCtrl, _startCtrl, _endCtrl, _kmCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final start = DateTime.tryParse(_startCtrl.text.trim());
    final end = DateTime.tryParse(_endCtrl.text.trim());

    if (start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato de fechas inválido (debe ser AAAA-MM-DD)')),
      );
      return;
    }

    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha de fin debe ser posterior al inicio')),
      );
      return;
    }

    final year = int.tryParse(_yearCtrl.text.trim());
    if (year == null || year < 1900 || year > DateTime.now().year + 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El año del vehículo no es válido')),
      );
      return;
    }

    final insuredVal = double.tryParse(_valCtrl.text.trim());
    if (insuredVal == null || insuredVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El valor asegurado debe ser mayor a 0')),
      );
      return;
    }

    final prima = double.tryParse(_primaCtrl.text.trim());
    if (prima == null || prima < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La prima mensual debe ser un valor positivo')),
      );
      return;
    }

    final km = int.tryParse(_kmCtrl.text.trim());
    if (km == null || km < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El kilometraje de emisión debe ser un entero >= 0')),
      );
      return;
    }

    Navigator.of(context).pop(CreatePolicyRequest(
      number: _numCtrl.text.trim(),
      clientId: _selectedClientDoc,
      vehicleId: widget.initialPolicy?.vehicleId ?? widget.initialRequest?.vehicleId,
      vehicle: VehicleModel(
        plate: _plateCtrl.text.trim().toUpperCase(),
        brand: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: year,
      ),
      startDate: start,
      endDate: end,
      status: _status,
      insuredValue: insuredVal,
      monthlyPremium: prima,
      emissionMileage: km,
      coverages: List<String>.from(_selectedCoverages),
      deductibles: widget.initialPolicy?.deductibles ?? widget.initialRequest?.deductibles ?? const [],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialPolicy == null ? 'Nueva Póliza Vehicular' : 'Emisión de Póliza (Borrador)'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _numCtrl, decoration: const InputDecoration(labelText: 'Número de Póliza'), validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: const [DropdownMenuItem(value: 'activa', child: Text('Activa')), DropdownMenuItem(value: 'vencida', child: Text('Vencida')), DropdownMenuItem(value: 'cancelada', child: Text('Cancelada'))],
                        onChanged: (v) => setState(() => _status = v ?? 'activa'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.clients.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedClientDoc.isNotEmpty ? _selectedClientDoc : null,
                    decoration: const InputDecoration(labelText: 'Cliente Titular'),
                    items: widget.clients.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.nombres} (${c.identificacion})'))).toList(),
                    onChanged: (v) => setState(() => _selectedClientDoc = v ?? ''),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'Marca'), validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _modelCtrl, decoration: const InputDecoration(labelText: 'Modelo'), validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _yearCtrl,
                        decoration: const InputDecoration(labelText: 'Año'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          final y = int.tryParse(v.trim());
                          if (y == null || y < 1900 || y > DateTime.now().year + 1) return 'Año inválido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _plateCtrl,
                  decoration: const InputDecoration(labelText: 'Placa Vehicular (Formato ANT, ej. PBA-1234)'),
                  validator: (v) => PlateValidator.isValid(v ?? '') ? null : 'Placa no cumple formato ANT',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _valCtrl,
                        decoration: const InputDecoration(labelText: 'Valor Asegurado (USD)'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          final val = double.tryParse(v.trim());
                          if (val == null || val <= 0) return 'Valor inválido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _primaCtrl,
                        decoration: const InputDecoration(labelText: 'Prima Mensual (USD)'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          final p = double.tryParse(v.trim());
                          if (p == null || p < 0) return 'Prima inválida';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _kmCtrl,
                  decoration: const InputDecoration(labelText: 'Kilometraje de Emisión (Snapshot inmutable)'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    final k = int.tryParse(v.trim());
                    if (k == null || k < 0) return 'Kilometraje inválido (debe ser >= 0)';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startCtrl,
                        decoration: const InputDecoration(labelText: 'Inicio (AAAA-MM-DD)'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if (DateTime.tryParse(v.trim()) == null) return 'Formato AAAA-MM-DD';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _endCtrl,
                        decoration: const InputDecoration(labelText: 'Fin (AAAA-MM-DD)'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if (DateTime.tryParse(v.trim()) == null) return 'Formato AAAA-MM-DD';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Coberturas Contratadas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ..._allCoverages.map((cov) => CheckboxListTile(
                  dense: true,
                  title: Text(cov, style: const TextStyle(fontSize: 13)),
                  value: _selectedCoverages.contains(cov),
                  onChanged: (on) => setState(() => on == true ? _selectedCoverages.add(cov) : _selectedCoverages.remove(cov)),
                )),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
