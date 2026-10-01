import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';

class UsersTabView extends StatefulWidget {
  const UsersTabView({super.key});

  @override
  State<UsersTabView> createState() => _UsersTabViewState();
}

class _UsersTabViewState extends State<UsersTabView> {
  List<Map<String, dynamic>> _usuarios = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  String? _getToken() {
    final state = context.read<AuthBloc>().state;
    return state is AuthSuccess ? state.token : null;
  }

  //  CERO PERSISTENCIAS ZOMBIE: Consulta a la API REST, no a Hive
  Future<void> _cargarUsuarios() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/clientes'),
        headers: ApiConfig.authHeaders(_getToken()),
      ).timeout(ApiConfig.defaultTimeout);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _usuarios = list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          _isLoading = false;
        });
      } else {
        setState(() { _isLoading = false; _errorMessage = 'Error ${res.statusCode}: ${res.body}'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && _usuarios.isEmpty) {
      return ErrorView(message: _errorMessage!, onRetry: _cargarUsuarios);
    }

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
                IconButton(
                  tooltip: 'Refrescar',
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _cargarUsuarios,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_usuarios.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No hay usuarios registrados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, height: 1.5),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppTheme.lightBg),
                    columns: const [
                      DataColumn(label: Text('Correo', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Identificación', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _usuarios.map((u) {
                      final email = u['email']?.toString() ?? '';
                      final nombre = u['nombres']?.toString() ?? u['name']?.toString() ?? '';
                      final identificacion = u['identificacion']?.toString() ?? '';
                      final isActive = u['activo'] != false;
                      return DataRow(cells: [
                        DataCell(Text(email, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(nombre)),
                        DataCell(Text(identificacion)),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isActive ? 'ACTIVO' : 'INACTIVO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
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
