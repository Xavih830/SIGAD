import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/core/utils/plate_validator.dart';

class PolicyFormDialog extends StatefulWidget {
  final PolicyModel? initialPolicy;
  final List<Map<String, dynamic>> clients;

  const PolicyFormDialog({super.key, this.initialPolicy, required this.clients});

  @override
  State<PolicyFormDialog> createState() => _PolicyFormDialogState();
}

class _PolicyFormDialogState extends State<PolicyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numCtrl, _brandCtrl, _modelCtrl, _yearCtrl, _plateCtrl, _valCtrl, _primaCtrl, _startCtrl, _endCtrl;
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
    _numCtrl = TextEditingController(text: p?.number ?? '');
    _brandCtrl = TextEditingController(text: p?.vehicle?.brand ?? '');
    _modelCtrl = TextEditingController(text: p?.vehicle?.model ?? '');
    _yearCtrl = TextEditingController(text: p?.vehicle?.year.toString() ?? '');
    _plateCtrl = TextEditingController(text: p?.vehicle?.plate ?? '');
    _valCtrl = TextEditingController(text: p != null ? p.insuredValue.toStringAsFixed(2) : '');
    _primaCtrl = TextEditingController(text: p != null ? p.monthlyPremium.toStringAsFixed(2) : '');
    _startCtrl = TextEditingController(text: p != null ? p.startDate.toIso8601String().substring(0, 10) : DateTime.now().toIso8601String().substring(0, 10));
    _endCtrl = TextEditingController(text: p != null ? p.endDate.toIso8601String().substring(0, 10) : DateTime.now().add(const Duration(days: 365)).toIso8601String().substring(0, 10));

    _status = p?.status ?? 'activa';
    _selectedClientDoc = p?.clientId ?? (widget.clients.isNotEmpty ? (widget.clients.first['id']?.toString() ?? '') : '');
    _selectedCoverages.addAll(p != null ? p.coverages : ['Responsabilidad Civil']);

  }

  @override
  void dispose() {
    for (final c in [_numCtrl, _brandCtrl, _modelCtrl, _yearCtrl, _plateCtrl, _valCtrl, _primaCtrl, _startCtrl, _endCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final start = DateTime.tryParse(_startCtrl.text) ?? DateTime.now();
    final end = DateTime.tryParse(_endCtrl.text) ?? DateTime.now().add(const Duration(days: 365));

    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La fecha de fin debe ser posterior al inicio')));
      return;
    }

    Navigator.of(context).pop(PolicyModel(
      id: widget.initialPolicy?.id ?? 'pol-${DateTime.now().millisecondsSinceEpoch}',
      number: _numCtrl.text.trim(),
      clientId: _selectedClientDoc,
      vehicleId: widget.initialPolicy?.vehicleId ?? 'veh-${DateTime.now().millisecondsSinceEpoch}',
      vehicle: VehicleModel(
        plate: _plateCtrl.text.trim().toUpperCase(),
        brand: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: int.tryParse(_yearCtrl.text.trim()) ?? 2022,
      ),
      startDate: start,
      endDate: end,
      status: _status,
      insuredValue: double.tryParse(_valCtrl.text.trim()) ?? 0.0,
      monthlyPremium: double.tryParse(_primaCtrl.text.trim()) ?? 0.0,
      emissionMileage: 0,
      coverages: List.from(_selectedCoverages),
      deductibles: widget.initialPolicy?.deductibles ?? const [],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialPolicy == null ? 'Nueva Póliza Vehicular' : 'Editar Póliza'),
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
                    items: widget.clients.map((c) => DropdownMenuItem(value: c['id']?.toString() ?? '', child: Text('${c['name']} (${c['id']})'))).toList(),
                    onChanged: (v) => setState(() => _selectedClientDoc = v ?? ''),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'Marca'), validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _modelCtrl, decoration: const InputDecoration(labelText: 'Modelo'), validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _yearCtrl, decoration: const InputDecoration(labelText: 'Año'), keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null)),
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
                    Expanded(child: TextFormField(controller: _valCtrl, decoration: const InputDecoration(labelText: 'Valor Asegurado (USD)'), keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _primaCtrl, decoration: const InputDecoration(labelText: 'Prima Mensual (USD)'), keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _startCtrl, decoration: const InputDecoration(labelText: 'Inicio (AAAA-MM-DD)'), validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _endCtrl, decoration: const InputDecoration(labelText: 'Fin (AAAA-MM-DD)'), validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null)),
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
