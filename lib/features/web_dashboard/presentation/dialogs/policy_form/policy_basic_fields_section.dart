import 'package:flutter/material.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/utils/plate_validator.dart';

class PolicyBasicFieldsSection extends StatelessWidget {
  final TextEditingController numCtrl;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final List<ClientModel> clients;
  final String selectedClientDoc;
  final ValueChanged<String> onClientChanged;
  final TextEditingController brandCtrl;
  final TextEditingController modelCtrl;
  final TextEditingController yearCtrl;
  final TextEditingController plateCtrl;
  final TextEditingController valCtrl;
  final TextEditingController primaCtrl;
  final TextEditingController kmCtrl;
  final TextEditingController startCtrl;
  final TextEditingController endCtrl;

  const PolicyBasicFieldsSection({
    super.key,
    required this.numCtrl,
    required this.status,
    required this.onStatusChanged,
    required this.clients,
    required this.selectedClientDoc,
    required this.onClientChanged,
    required this.brandCtrl,
    required this.modelCtrl,
    required this.yearCtrl,
    required this.plateCtrl,
    required this.valCtrl,
    required this.primaCtrl,
    required this.kmCtrl,
    required this.startCtrl,
    required this.endCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: numCtrl,
                decoration: const InputDecoration(labelText: 'Número de Póliza'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: const [
                  DropdownMenuItem(value: 'activa', child: Text('Activa')),
                  DropdownMenuItem(value: 'vencida', child: Text('Vencida')),
                  DropdownMenuItem(value: 'cancelada', child: Text('Cancelada')),
                ],
                onChanged: (v) => onStatusChanged(v ?? 'activa'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (clients.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: selectedClientDoc.isNotEmpty ? selectedClientDoc : null,
            decoration: const InputDecoration(labelText: 'Cliente Titular'),
            items: clients
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.nombres} (${c.identificacion})'),
                  ),
                )
                .toList(),
            onChanged: (v) => onClientChanged(v ?? ''),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: brandCtrl,
                decoration: const InputDecoration(labelText: 'Marca'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: 'Modelo'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: yearCtrl,
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
          controller: plateCtrl,
          decoration: const InputDecoration(labelText: 'Placa Vehicular (Formato ANT, ej. PBA-1234)'),
          validator: (v) => PlateValidator.isValid(v ?? '') ? null : 'Placa no cumple formato ANT',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: valCtrl,
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
                controller: primaCtrl,
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
          controller: kmCtrl,
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
                controller: startCtrl,
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
                controller: endCtrl,
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
      ],
    );
  }
}
