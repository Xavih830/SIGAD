import 'package:flutter/material.dart';
import 'package:sigad/core/models/catalog_model.dart';

class AssistanceFormDialog extends StatefulWidget {
  final AssistanceModel? initialAssistance;

  const AssistanceFormDialog({super.key, this.initialAssistance});

  @override
  State<AssistanceFormDialog> createState() => _AssistanceFormDialogState();
}

class _AssistanceFormDialogState extends State<AssistanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _iconCtrl;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAssistance;
    _titleCtrl = TextEditingController(text: a?.title ?? '');
    _descCtrl = TextEditingController(text: a?.description ?? '');
    _phoneCtrl = TextEditingController(text: a?.emergencyPhone ?? '');
    _iconCtrl = TextEditingController(text: a?.icon ?? 'phone');
    _active = a?.active ?? true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final request = CreateAssistanceRequest(
      titulo: _titleCtrl.text.trim(),
      descripcion: _descCtrl.text.trim(),
      telefonoEmergencia: _phoneCtrl.text.trim(),
      icono: _iconCtrl.text.trim().isEmpty ? 'phone' : _iconCtrl.text.trim(),
      activo: _active,
    );

    Navigator.of(context).pop(request);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Servicio de Asistencia'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Título del Servicio *'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Ingrese al menos 2 caracteres'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción detallada *'),
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'Ingrese al menos 5 caracteres'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Teléfono de Emergencia *'),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Ingrese un teléfono de contacto'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _iconCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Identificador de Ícono',
                    hintText: 'phone, local_shipping, build, etc.',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Servicio Activo'),
                  value: _active,
                  onChanged: (val) => setState(() => _active = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
