import 'package:flutter/material.dart';
import 'package:sigad/core/services/hive_helper.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/sha256_helper.dart';

class UsersTabView extends StatefulWidget {
  const UsersTabView({super.key});

  @override
  State<UsersTabView> createState() => _UsersTabViewState();
}

class _UsersTabViewState extends State<UsersTabView> {
  List<Map<String, dynamic>> _getUsers() {
    return HiveHelper.usersBox.values.map((u) => Map<String, dynamic>.from(u)).toList();
  }

  void _openUserDialog([Map<String, dynamic>? initial]) {
    final isEdit = initial != null;
    final emailCtrl = TextEditingController(text: initial?['email'] ?? '');
    final nameCtrl = TextEditingController(text: initial?['name'] ?? '');
    final passCtrl = TextEditingController();
    String role = initial?['role'] ?? 'client';
    bool isActive = initial?['isActive'] ?? true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(isEdit ? 'Editar Usuario' : 'Nuevo Usuario'),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailCtrl,
                    enabled: !isEdit,
                    decoration: const InputDecoration(labelText: 'Correo Electrónico'),
                    validator: (v) => (v == null || v.isEmpty || !v.contains('@')) ? 'Correo inválido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre Completo'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passCtrl,
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: const [
                      DropdownMenuItem(value: 'admin_system', child: Text('Administrador del Sistema')),
                      DropdownMenuItem(value: 'admin_rjseguros', child: Text('Administrador RJ Seguros')),
                      DropdownMenuItem(value: 'client', child: Text('Cliente Asegurado')),
                    ],
                    onChanged: (v) => setDlg(() => role = v ?? 'client'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Cuenta Activa'),
                    value: isActive,
                    onChanged: (v) => setDlg(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final email = emailCtrl.text.trim().toLowerCase();
                  final userMap = {
                    'email': email,
                    'name': nameCtrl.text.trim(),
                    'role': role,
                    'isActive': isActive,
                    if (!isEdit) 'passwordHash': Sha256Helper.hash(passCtrl.text) else 'passwordHash': initial['passwordHash'],
                  };
                  await HiveHelper.usersBox.put(email, userMap);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    setState(() {});
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteUser(String email) async {
    await HiveHelper.usersBox.delete(email);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final users = _getUsers();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cuentas de Acceso al Sistema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => _openUserDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo Usuario'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppTheme.lightBg),
                  columns: const [
                    DataColumn(label: Text('Correo', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Rol', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: users.map((u) {
                    final email = u['email']?.toString() ?? '';
                    final isActive = u['isActive'] == true;
                    return DataRow(cells: [
                      DataCell(Text(email, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(u['name']?.toString() ?? '')),
                      DataCell(Text(u['role']?.toString() ?? '')),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: isActive ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text(isActive ? 'ACTIVO' : 'INACTIVO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? Colors.green.shade700 : Colors.red.shade700)),
                      )),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20), tooltip: 'Editar', onPressed: () => _openUserDialog(u)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor, size: 20), tooltip: 'Eliminar', onPressed: () => _deleteUser(email)),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
