import 'package:flutter/material.dart';
import 'package:sigad/core/models/catalog_model.dart';

class WorkshopFormDialog extends StatefulWidget {
  final WorkshopModel? initialWorkshop;

  const WorkshopFormDialog({super.key, this.initialWorkshop});

  @override
  State<WorkshopFormDialog> createState() => _WorkshopFormDialogState();
}

class _WorkshopFormDialogState extends State<WorkshopFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _cityCtrl;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final w = widget.initialWorkshop;
    _nameCtrl = TextEditingController(text: w?.name ?? '');
    _addressCtrl = TextEditingController(text: w?.address ?? '');
    _phoneCtrl = TextEditingController(text: w?.phone ?? '');
    _cityCtrl = TextEditingController(text: w?.city ?? '');
    _active = w?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final request = CreateWorkshopRequest(
      nombre: _nameCtrl.text.trim(),
      direccion: _addressCtrl.text.trim(),
      telefono: _phoneCtrl.text.trim(),
      ciudad: _cityCtrl.text.trim(),
      activo: _active,
    );

    Navigator.of(context).pop(request);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Taller Autorizado'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del Taller *'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Ingrese al menos 2 caracteres'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'Dirección *'),
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'Ingrese al menos 5 caracteres'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Teléfono de Contacto *'),
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'Ingrese un teléfono válido'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityCtrl,
                  decoration: const InputDecoration(labelText: 'Ciudad *'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Ingrese la ciudad'
                      : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Taller Activo'),
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
