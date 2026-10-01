import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/repositories/clients_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';

class UsersTabView extends StatefulWidget {
  final ClientsRepository? clientsRepository;

  const UsersTabView({super.key, this.clientsRepository});

  @override
  State<UsersTabView> createState() => _UsersTabViewState();
}

class _UsersTabViewState extends State<UsersTabView> {
  late final ClientsRepository _repository;
  List<ClientModel> _usuarios = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.clientsRepository ?? ClientsRepository();
    _cargarUsuarios();
  }

  String? _getToken() {
    final state = context.read<AuthBloc>().state;
    return state is AuthSuccess ? state.token : null;
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await _repository.getClients(token: _getToken());
      if (!mounted) return;
      setState(() {
        _usuarios = list;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
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
                      return DataRow(cells: [
                        DataCell(Text(u.email ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(u.nombres)),
                        DataCell(Text(u.identificacion)),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ACTIVO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
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
