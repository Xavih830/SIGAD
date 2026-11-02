import 'package:flutter/material.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/utils/ecuadorian_id_validator.dart';
import 'package:sigad/shared/widgets/sigad_text_field.dart';

class ClientFormDialog extends StatefulWidget {
  final ClientModel? initialClient;

  const ClientFormDialog({super.key, this.initialClient});

  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    final c = widget.initialClient;
    _idCtrl = TextEditingController(text: c?.identificacion ?? '');
    _nameCtrl = TextEditingController(text: c?.nombres ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _phoneCtrl = TextEditingController(text: c?.telefono ?? '');
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (widget.initialClient != null) {
      final request = UpdateClientRequest(
        nombres: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        telefono: _phoneCtrl.text.trim(),
      );
      Navigator.of(context).pop(request);
    } else {
      final request = CreateClientRequest(
        identificacion: _idCtrl.text.trim(),
        nombres: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        telefono: _phoneCtrl.text.trim(),
      );
      Navigator.of(context).pop(request);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialClient != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Cliente' : 'Nuevo Cliente'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SigadTextField(
                controller: _idCtrl,
                readOnly: isEditing,
                label: 'Identificación (Cédula o RUC)',
                hintText: 'ej. 0926687856 o 1790016919001',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'La identificación es requerida';
                  if (!EcuadorianIdValidator.isValidIdentificacion(v)) return 'Identificación no válida (Cédula o RUC)';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SigadTextField(
                controller: _nameCtrl,
                label: 'Nombre Completo',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
              ),
              const SizedBox(height: 12),
              SigadTextField(
                controller: _emailCtrl,
                label: 'Correo Electrónico',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El correo es requerido';
                  if (!v.contains('@') || !v.contains('.')) return 'Correo inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SigadTextField(
                controller: _phoneCtrl,
                label: 'Teléfono Móvil (10 dígitos)',
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El teléfono es requerido' : null,
              ),
            ],
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

