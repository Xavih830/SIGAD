import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sigad/core/services/hive_helper.dart';
import 'package:sigad/core/services/notifications_manager.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/ecuadorian_id_validator.dart';
import 'package:sigad/core/utils/sha256_helper.dart';
import 'package:sigad/core/widgets/sigad_logo.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/pages/login_page.dart';

import 'package:sigad/core/utils/print/print_helper.dart';

class WebDashboardPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const WebDashboardPage({super.key, required this.user});

  @override
  State<WebDashboardPage> createState() => _WebDashboardPageState();
}

class _WebDashboardPageState extends State<WebDashboardPage> {
  String _activeTab = 'policies'; // policies, clients, users, ocr, reports, alerts
  
  // Search / Filters
  final _searchController = TextEditingController();
  String _policyTypeFilter = 'all'; // all, liviano, pesado
  String _policyStatusFilter = 'all'; // all, activa, vencida, cancelada
  
  // OCR State
  String? _selectedOcrMock;
  Map<String, dynamic>? _ocrExtractedData;
  Map<String, String> _ocrConfidence = {}; // 'high', 'low', 'none'
  
  // Reports State
  DateTime _reportStartDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _reportEndDate = DateTime.now().add(const Duration(days: 30));

  // Alerts State
  double _alertDaysThreshold = 30; // 30, 60, 90

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerPrint() {
    if (kIsWeb) {
      triggerPrint();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La exportación por impresión solo está disponible en entorno Web.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = widget.user['role'] as String;
    final isSystemAdmin = userRole == 'admin_system';
    
    // Fallback if system admin tries to view policies pages but we default them
    if (_activeTab == 'users' && !isSystemAdmin) {
      _activeTab = 'policies';
    }

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial || state is AuthFailure || state is AuthLockedOut) {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (c, a1, a2) => const LoginPage(),
              transitionsBuilder: (c, anim, a2, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.lightBg,
        body: Row(
          children: [
            // Sidebar
            _buildSidebar(isSystemAdmin),
            
            // Main Content
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Header
                    _buildHeader(),
                    const SizedBox(height: 24),
                    // Tab View
                    Expanded(
                      child: _buildActiveTabContent(isSystemAdmin),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isSystemAdmin) {
    return Container(
      width: 280,
      color: const Color(0xFF111827), // Dark slate premium sidebar
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Name
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const SigadLogo(size: 44, showLabel: false),
                const SizedBox(width: 12),
                Text(
                  'SIGAD Web',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),
          
          // Navigation
          _buildSidebarItem(
            icon: Icons.description_outlined,
            title: 'Pólizas Vehiculares',
            tabId: 'policies',
          ),
          _buildSidebarItem(
            icon: Icons.people_outline,
            title: 'Clientes',
            tabId: 'clients',
          ),
          if (isSystemAdmin)
            _buildSidebarItem(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Usuarios del Sistema',
              tabId: 'users',
            ),
          _buildSidebarItem(
            icon: Icons.document_scanner_outlined,
            title: 'Lector Documental OCR',
            tabId: 'ocr',
          ),
          _buildSidebarItem(
            icon: Icons.analytics_outlined,
            title: 'Reportes y Estadísticas',
            tabId: 'reports',
          ),
          _buildSidebarItem(
            icon: Icons.notification_important_outlined,
            title: 'Alertas de Vencimiento',
            tabId: 'alerts',
          ),
          
          const Spacer(),
          
          // Current User Profile Summary
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user['name'] ?? '',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.user['role'] == 'admin_system' ? 'Sys Admin' : 'Admin RJ',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white60),
                  onPressed: () {
                    context.read<AuthBloc>().add(LogoutRequested());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({required IconData icon, required String title, required String tabId}) {
    final isActive = _activeTab == tabId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = tabId;
            _searchController.clear();
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: isActive ? Colors.white : Colors.white60, size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white60,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String headingText = '';
    switch (_activeTab) {
      case 'policies':
        headingText = 'Gestión de Pólizas Vehiculares';
        break;
      case 'clients':
        headingText = 'Control de Clientes';
        break;
      case 'users':
        headingText = 'Cuentas de Usuarios';
        break;
      case 'ocr':
        headingText = 'Lector OCR Inteligente';
        break;
      case 'reports':
        headingText = 'Informes Operativos';
        break;
      case 'alerts':
        headingText = 'Notificaciones de Vencimiento';
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headingText,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Panel de control de RJ Seguros (Persistencia Local)',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveTabContent(bool isSystemAdmin) {
    switch (_activeTab) {
      case 'policies':
        return _buildPoliciesView();
      case 'clients':
        return _buildClientsView();
      case 'users':
        return isSystemAdmin ? _buildUsersView() : const SizedBox();
      case 'ocr':
        return _buildOcrView();
      case 'reports':
        return _buildReportsView();
      case 'alerts':
        return _buildAlertsView();
      default:
        return const SizedBox();
    }
  }

  // ============================================
  // TAB: POLICIES VIEW
  // ============================================
  Widget _buildPoliciesView() {
    final query = _searchController.text.trim().toLowerCase();
    
    final allPolicies = HiveHelper.policiesBox.values
        .map((p) => Map<String, dynamic>.from(p))
        .where((p) => p['isDeleted'] != true)
        .toList();

    final filteredPolicies = allPolicies.where((p) {
      final matchesSearch = p['number'].toString().toLowerCase().contains(query) ||
          p['plate'].toString().toLowerCase().contains(query) ||
          p['clientName'].toString().toLowerCase().contains(query) ||
          p['clientDoc'].toString().toLowerCase().contains(query);

      final matchesType = _policyTypeFilter == 'all' || p['type'] == _policyTypeFilter;
      final matchesStatus = _policyStatusFilter == 'all' || p['status'] == _policyStatusFilter;

      return matchesSearch && matchesType && matchesStatus;
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Controls row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por Nro. Póliza, Placa, Asegurado o Cédula...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _policyTypeFilter,
                  onChanged: (v) => setState(() => _policyTypeFilter = v!),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos los Tipos')),
                    DropdownMenuItem(value: 'liviano', child: Text('Vehículo Liviano')),
                    DropdownMenuItem(value: 'pesado', child: Text('Vehículo Pesado')),
                  ],
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _policyStatusFilter,
                  onChanged: (v) => setState(() => _policyStatusFilter = v!),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos los Estados')),
                    DropdownMenuItem(value: 'activa', child: Text('Activa')),
                    DropdownMenuItem(value: 'vencida', child: Text('Vencida')),
                    DropdownMenuItem(value: 'cancelada', child: Text('Cancelada')),
                  ],
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  onPressed: () => _showPolicyFormDialog(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Crear Póliza'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Table view
            Expanded(
              child: filteredPolicies.isEmpty
                  ? const Center(child: Text('No se encontraron pólizas.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(AppTheme.lightBg),
                        columns: const [
                          DataColumn(label: Text('Nro. Póliza', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Asegurado', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Placa', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Fin Vigencia', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filteredPolicies.map((p) {
                          return DataRow(cells: [
                            DataCell(Text(p['number'], style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(p['clientName'])),
                            DataCell(Text(p['plate'])),
                            DataCell(Text(p['type'] == 'pesado' ? 'Pesado' : 'Liviano')),
                            DataCell(Text(p['endDate'])),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: p['status'] == 'activa'
                                    ? Colors.green.shade50
                                    : p['status'] == 'vencida'
                                        ? Colors.red.shade50
                                        : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p['status'].toString().toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: p['status'] == 'activa'
                                      ? Colors.green.shade700
                                      : p['status'] == 'vencida'
                                          ? Colors.red.shade700
                                          : Colors.grey.shade700,
                                ),
                              ),
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.info_outline, color: AppTheme.accentColor),
                                  tooltip: 'Detalle e Historial',
                                  onPressed: () => _showPolicyDetailsDialog(p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                  tooltip: 'Editar',
                                  onPressed: () => _showPolicyFormDialog(policy: p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_outlined, color: Colors.purple),
                                  tooltip: 'Duplicar',
                                  onPressed: () => _duplicatePolicy(p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                                  tooltip: 'Eliminar',
                                  onPressed: () => _confirmDeletePolicy(p['number']),
                                ),
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

  void _showPolicyFormDialog({Map<String, dynamic>? policy}) {
    final isEditing = policy != null;
    final formKey = GlobalKey<FormState>();

    final numberController = TextEditingController(text: isEditing ? policy['number'] : '');
    final brandController = TextEditingController(text: isEditing ? policy['vehicleBrand'] : '');
    final modelController = TextEditingController(text: isEditing ? policy['vehicleModel'] : '');
    final yearController = TextEditingController(text: isEditing ? policy['vehicleYear'].toString() : '');
    final colorController = TextEditingController(text: isEditing ? policy['vehicleColor'] : '');
    final plateController = TextEditingController(text: isEditing ? policy['plate'] : '');
    final valueController = TextEditingController(text: isEditing ? policy['value'].toString() : '');
    final primaController = TextEditingController(text: isEditing ? policy['prima'].toString() : '');
    final startController = TextEditingController(text: isEditing ? policy['startDate'] : '');
    final endController = TextEditingController(text: isEditing ? policy['endDate'] : '');
    final tonnageController = TextEditingController(
        text: isEditing && policy['tonnage'] != null ? policy['tonnage'].toString() : '');

    String type = isEditing ? policy['type'] : 'liviano';
    String status = isEditing ? policy['status'] : 'activa';
    
    // Client Dropdown Setup
    final clients = HiveHelper.clientsBox.values.map((c) => Map<String, dynamic>.from(c)).toList();
    String? selectedClientDoc = isEditing ? policy['clientDoc'] : (clients.isNotEmpty ? clients.first['id'] : null);

    // Coverages Setup
    final List<String> availableCoverages = [
      'Daños propios',
      'Responsabilidad civil',
      'Accidentes personales',
      'Asistencia en carretera',
      'Robo total',
      'Carga transportada',
      'Responsabilidad civil ampliada',
    ];
    List<String> selectedCoverages = isEditing ? List<String>.from(policy['coverages']) : [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Editar Póliza Vehicular' : 'Crear Póliza Vehicular',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 700,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Form rows
                      if (!isEditing) ...[
                        TextFormField(
                          controller: numberController,
                          style: const TextStyle(color: AppTheme.textDark),
                          decoration: const InputDecoration(labelText: 'Número de Póliza (Ej: POL-VL-2024-001)'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'El número de póliza es requerido';
                            if (HiveHelper.policiesBox.containsKey(value.trim())) {
                              return 'Ya existe una póliza con este número';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      DropdownButtonFormField<String>(
                        value: selectedClientDoc,
                        decoration: const InputDecoration(labelText: 'Asegurado (Cliente)'),
                        items: clients.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['id'],
                            child: Text('${c['name']} (${c['id']})'),
                          );
                        }).toList(),
                        onChanged: (v) => setDialogState(() => selectedClientDoc = v),
                        validator: (value) => value == null ? 'Selecciona un asegurado' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: type,
                              decoration: const InputDecoration(labelText: 'Tipo de Vehículo'),
                              items: const [
                                DropdownMenuItem(value: 'liviano', child: Text('Vehículo Liviano')),
                                DropdownMenuItem(value: 'pesado', child: Text('Vehículo Pesado')),
                              ],
                              onChanged: isEditing
                                  ? null // Type cannot be modified in edit according to standard systems, or we can lock it
                                  : (v) {
                                      setDialogState(() {
                                        type = v!;
                                        if (type == 'liviano') {
                                          selectedCoverages.remove('Carga transportada');
                                          selectedCoverages.remove('Responsabilidad civil ampliada');
                                        }
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: status,
                              decoration: const InputDecoration(labelText: 'Estado'),
                              items: const [
                                DropdownMenuItem(value: 'activa', child: Text('Activa')),
                                DropdownMenuItem(value: 'vencida', child: Text('Vencida')),
                                DropdownMenuItem(value: 'cancelada', child: Text('Cancelada')),
                              ],
                              onChanged: (v) => setDialogState(() => status = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: brandController,
                              style: const TextStyle(color: AppTheme.textDark),
                              decoration: const InputDecoration(labelText: 'Marca'),
                              validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: modelController,
                              style: const TextStyle(color: AppTheme.textDark),
                              decoration: const InputDecoration(labelText: 'Modelo'),
                              validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: yearController,
                              style: const TextStyle(color: AppTheme.textDark),
                              decoration: const InputDecoration(labelText: 'Año (Ej: 2020)'),
                              keyboardType: TextInputType.number,
                              validator: (v) => int.tryParse(v ?? '') == null ? 'Año inválido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: colorController,
                              style: const TextStyle(color: AppTheme.textDark),
                              decoration: const InputDecoration(labelText: 'Color'),
                              validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: plateController,
                              style: const TextStyle(color: AppTheme.textDark),
                              decoration: const InputDecoration(labelText: 'Placa (Ej: GPA-1234)'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Placa requerida';
                                // Plate uniqueness for ACTIVE policies
                                final trimmedPlate = value.trim().toUpperCase();
                                final activePlates = HiveHelper.policiesBox.values
                                    .map((pol) => Map<String, dynamic>.from(pol))
                                    .where((pol) =>
                                        pol['plate'] == trimmedPlate &&
                                        pol['status'] == 'activa' &&
                                        pol['isDeleted'] != true &&
                                        (!isEditing || pol['number'] != policy['number']))
                                    .toList();
                                if (activePlates.isNotEmpty) {
                                  return 'Ya existe una póliza activa asociada a esta placa';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      if (type == 'pesado') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: tonnageController,
                          style: const TextStyle(color: AppTheme.textDark),
                          decoration: const InputDecoration(labelText: 'Tonelaje (Mandatorio para Pesados)'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'El tonelaje es obligatorio para pesados';
                            if (double.tryParse(v) == null) return 'Tonelaje inválido';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: valueController,
                              style: const TextStyle(color: AppTheme.textDark),
                              decoration: const InputDecoration(labelText: 'Valor Asegurado (USD)'),
                              keyboardType: TextInputType.number,
                              validator: (v) => double.tryParse(v ?? '') == null ? 'Monto inválido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: primaController,
                              style: const TextStyle(color: AppTheme.textDark),
                              decoration: const InputDecoration(labelText: 'Prima Mensual (USD)'),
                              keyboardType: TextInputType.number,
                              validator: (v) => double.tryParse(v ?? '') == null ? 'Monto inválido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: startController,
                              style: const TextStyle(color: AppTheme.textDark),
                              decoration: const InputDecoration(labelText: 'Inicio Vigencia (AAAA-MM-DD)'),
                              validator: (v) {
                                if (DateTime.tryParse(v ?? '') == null) return 'Fecha inválida';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: endController,
                              style: const TextStyle(color: AppTheme.textDark),
                              decoration: const InputDecoration(labelText: 'Fin Vigencia (AAAA-MM-DD)'),
                              validator: (v) {
                                if (DateTime.tryParse(v ?? '') == null) return 'Fecha inválida';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Coberturas Contratadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      // List of coverage checkboxes
                      ...availableCoverages.map((cov) {
                        // Hide heavy specific coverages if type is light
                        if (type == 'liviano' &&
                            (cov == 'Carga transportada' || cov == 'Responsabilidad civil ampliada')) {
                          return const SizedBox();
                        }
                        return CheckboxListTile(
                          title: Text(cov, style: const TextStyle(fontSize: 14)),
                          value: selectedCoverages.contains(cov),
                          onChanged: (selected) {
                            setDialogState(() {
                              if (selected == true) {
                                selectedCoverages.add(cov);
                              } else {
                                selectedCoverages.remove(cov);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final selectedClient = clients.firstWhere((c) => c['id'] == selectedClientDoc);
                    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

                    if (isEditing) {
                      // Logic for edit logs/history
                      final oldPolicy = Map<String, dynamic>.from(policy);
                      final List<dynamic> oldHistory = List.from(oldPolicy['changesHistory'] ?? []);
                      
                      final Map<String, dynamic> updatedFields = {
                        'clientEmail': selectedClient['email'],
                        'clientName': selectedClient['name'],
                        'clientDoc': selectedClient['id'],
                        'vehicleBrand': brandController.text,
                        'vehicleModel': modelController.text,
                        'vehicleYear': int.parse(yearController.text),
                        'vehicleColor': colorController.text,
                        'plate': plateController.text.toUpperCase(),
                        'coverages': selectedCoverages,
                        'value': double.parse(valueController.text),
                        'prima': double.parse(primaController.text),
                        'startDate': startController.text,
                        'endDate': endController.text,
                        'status': status,
                        'tonnage': type == 'pesado' ? double.parse(tonnageController.text) : 0.0,
                      };

                      // Diffing for changes log history
                      updatedFields.forEach((key, newVal) {
                        final oldVal = oldPolicy[key];
                        // Basic comparison
                        if (oldVal.toString() != newVal.toString()) {
                          oldHistory.add({
                            'date': nowStr,
                            'field': key,
                            'oldValue': oldVal.toString(),
                            'newValue': newVal.toString(),
                          });
                        }
                      });

                      final updatedPolicy = {
                        ...oldPolicy,
                        ...updatedFields,
                        'changesHistory': oldHistory,
                      };

                      await HiveHelper.policiesBox.put(policy['number'], updatedPolicy);
                      // Reschedule notifications for the client
                      NotificationsManager.schedulePolicyNotifications(updatedPolicy);
                    } else {
                      // Logic for new policy
                      final newPolicy = {
                        'number': numberController.text.trim(),
                        'clientEmail': selectedClient['email'],
                        'clientName': selectedClient['name'],
                        'clientDoc': selectedClient['id'],
                        'vehicleBrand': brandController.text,
                        'vehicleModel': modelController.text,
                        'vehicleYear': int.parse(yearController.text),
                        'vehicleColor': colorController.text,
                        'plate': plateController.text.toUpperCase(),
                        'type': type,
                        'coverages': selectedCoverages,
                        'value': double.parse(valueController.text),
                        'prima': double.parse(primaController.text),
                        'startDate': startController.text,
                        'endDate': endController.text,
                        'status': status,
                        'tonnage': type == 'pesado' ? double.parse(tonnageController.text) : 0.0,
                        'isDeleted': false,
                        'changesHistory': [],
                        'attachments': [],
                        'paymentStatus': 'Al día',
                        'lastPaymentDate': startController.text,
                      };

                      await HiveHelper.policiesBox.put(numberController.text.trim(), newPolicy);
                      NotificationsManager.schedulePolicyNotifications(newPolicy);
                    }

                    setState(() {});
                    Navigator.of(ctx).pop();
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        });
      },
    );
  }

  void _duplicatePolicy(Map<String, dynamic> policy) async {
    final number = 'DUP-${policy['number']}-${DateTime.now().millisecond}';
    final duplicated = {
      ...policy,
      'number': number,
      'startDate': '',
      'endDate': '',
      'status': 'borrador',
      'changesHistory': [],
      'attachments': [],
    };
    await HiveHelper.policiesBox.put(number, duplicated);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Póliza duplicada como borrador con número: $number')),
    );
  }

  void _confirmDeletePolicy(String number) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Está seguro de eliminar la póliza $number? Esta acción realizará una eliminación lógica.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              onPressed: () async {
                final policy = Map<String, dynamic>.from(HiveHelper.policiesBox.get(number));
                policy['isDeleted'] = true;
                await HiveHelper.policiesBox.put(number, policy);
                
                // Cancel scheduled alarms
                NotificationsManager.cancelPolicyNotifications(number);

                setState(() {});
                Navigator.of(ctx).pop();
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showPolicyDetailsDialog(Map<String, dynamic> policy) {
    final history = List<Map<String, dynamic>>.from(
        (policy['changesHistory'] as List?)?.map((h) => Map<String, dynamic>.from(h)) ?? []);

    final attachments = List<String>.from(policy['attachments'] ?? []);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDetailState) {
          return AlertDialog(
            title: Text('Detalle de Póliza: ${policy['number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 600,
              height: 500,
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: AppTheme.primaryColor,
                      tabs: [
                        Tab(text: 'General'),
                        Tab(text: 'Historial de Cambios'),
                        Tab(text: 'Documentos'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: General Info
                          ListView(
                            children: [
                              _buildStaticRow('Asegurado', policy['clientName']),
                              _buildStaticRow('Cédula', policy['clientDoc']),
                              _buildStaticRow('Placa', policy['plate']),
                              _buildStaticRow('Marca / Modelo', '${policy['vehicleBrand']} / ${policy['vehicleModel']}'),
                              _buildStaticRow('Año / Color', '${policy['vehicleYear']} / ${policy['vehicleColor']}'),
                              _buildStaticRow('Valor Asegurado', '\$${policy['value']}'),
                              _buildStaticRow('Prima Mensual', '\$${policy['prima']}'),
                              _buildStaticRow('Vigencia', '${policy['startDate']} a ${policy['endDate']}'),
                              _buildStaticRow('Estado', policy['status'].toString().toUpperCase()),
                              if (policy['type'] == 'pesado')
                                _buildStaticRow('Tonelaje', '${policy['tonnage']} t'),
                            ],
                          ),
                          // Tab 2: Logs/History
                          history.isEmpty
                              ? const Center(child: Text('No hay cambios registrados.'))
                              : ListView.builder(
                                  itemCount: history.length,
                                  itemBuilder: (c, idx) {
                                    final log = history[idx];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Campo: ${log['field']}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                Text(
                                                  log['date'],
                                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text('Valor anterior: ${log['oldValue']}',
                                                style: const TextStyle(fontSize: 13, color: AppTheme.errorColor)),
                                            Text('Valor nuevo: ${log['newValue']}',
                                                style: const TextStyle(fontSize: 13, color: AppTheme.successColor)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                          // Tab 3: Attachments
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  // Mock File Attachment
                                  final mockFile = 'poliza_vehicular_${policy['number']}_document.pdf';
                                  final updatedAttachments = List<String>.from(attachments)..add(mockFile);
                                  
                                  final polBox = HiveHelper.policiesBox;
                                  final updatedPol = {
                                    ...policy,
                                    'attachments': updatedAttachments,
                                  };
                                  polBox.put(policy['number'], updatedPol);
                                  
                                  setDetailState(() {
                                    attachments.add(mockFile);
                                  });
                                  setState(() {});
                                },
                                icon: const Icon(Icons.attach_file, color: Colors.white),
                                label: const Text('Adjuntar Documento Simulador'),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: attachments.isEmpty
                                    ? const Center(child: Text('No hay documentos adjuntos.'))
                                    : ListView.builder(
                                        itemCount: attachments.length,
                                        itemBuilder: (c, idx) {
                                          return ListTile(
                                            leading: const Icon(Icons.insert_drive_file, color: Colors.red),
                                            title: Text(attachments[idx], style: const TextStyle(fontSize: 13)),
                                            trailing: const Text('Local Path', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildStaticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  // ============================================
  // TAB: CLIENTS VIEW
  // ============================================
  Widget _buildClientsView() {
    final query = _searchController.text.trim().toLowerCase();
    
    final clients = HiveHelper.clientsBox.values
        .map((c) => Map<String, dynamic>.from(c))
        .toList();

    final filteredClients = clients.where((c) {
      return c['name'].toString().toLowerCase().contains(query) ||
          c['id'].toString().toLowerCase().contains(query);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Buscar clientes por nombre o cédula...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  onPressed: () => _showClientFormDialog(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Registrar Cliente'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: filteredClients.isEmpty
                  ? const Center(child: Text('No se encontraron clientes.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(AppTheme.lightBg),
                        columns: const [
                          DataColumn(label: Text('Nombre Completo', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Cédula / RUC', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Teléfono', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Pólizas Activas', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filteredClients.map((c) {
                          // Calculate active policy count
                          final policyCount = HiveHelper.policiesBox.values
                              .map((pol) => Map<String, dynamic>.from(pol))
                              .where((pol) =>
                                  pol['clientDoc'] == c['id'] &&
                                  pol['status'] == 'activa' &&
                                  pol['isDeleted'] != true)
                              .length;

                          return DataRow(cells: [
                            DataCell(Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(c['id'])),
                            DataCell(Text(c['phone'])),
                            DataCell(Text(c['email'])),
                            DataCell(Text(policyCount.toString())),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.account_box_outlined, color: AppTheme.accentColor),
                                  tooltip: 'Perfil y Pólizas',
                                  onPressed: () => _showClientProfileDialog(c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                  tooltip: 'Editar Contacto',
                                  onPressed: () => _showClientFormDialog(client: c),
                                ),
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

  void _showClientFormDialog({Map<String, dynamic>? client}) {
    final isEditing = client != null;
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: isEditing ? client['name'] : '');
    final docController = TextEditingController(text: isEditing ? client['id'] : '');
    final phoneController = TextEditingController(text: isEditing ? client['phone'] : '');
    final emailController = TextEditingController(text: isEditing ? client['email'] : '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Contacto Cliente' : 'Registrar Nuevo Cliente',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    enabled: !isEditing,
                    style: const TextStyle(color: AppTheme.textDark),
                    decoration: const InputDecoration(labelText: 'Nombre Completo'),
                    validator: (v) => v!.trim().isEmpty ? 'Nombre es obligatorio' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: docController,
                    enabled: !isEditing,
                    style: const TextStyle(color: AppTheme.textDark),
                    decoration: const InputDecoration(labelText: 'Cédula de Identidad (10 dígitos)'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Cédula es obligatoria';
                      if (!EcuadorianIdValidator.isValid(v.trim())) {
                        return 'Cédula ecuatoriana inválida (checksum incorrecto)';
                      }
                      if (!isEditing && HiveHelper.clientsBox.containsKey(v.trim())) {
                        return 'Esta cédula ya se encuentra registrada';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    style: const TextStyle(color: AppTheme.textDark),
                    decoration: const InputDecoration(labelText: 'Teléfono de Contacto'),
                    validator: (v) => v!.trim().isEmpty ? 'Teléfono es obligatorio' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    style: const TextStyle(color: AppTheme.textDark),
                    decoration: const InputDecoration(labelText: 'Correo electrónico'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email es obligatorio';
                      final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegExp.hasMatch(v.trim())) {
                        return 'Ingresa un correo electrónico válido';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  if (isEditing) {
                    final updatedClient = {
                      ...client,
                      'phone': phoneController.text.trim(),
                      'email': emailController.text.trim(),
                    };
                    await HiveHelper.clientsBox.put(client['id'], updatedClient);
                  } else {
                    final newClient = {
                      'id': docController.text.trim(),
                      'name': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'email': emailController.text.trim(),
                    };
                    await HiveHelper.clientsBox.put(docController.text.trim(), newClient);
                    
                    // Create a matching Client user account if it doesn't exist
                    final userEmail = emailController.text.trim().toLowerCase();
                    if (!HiveHelper.usersBox.containsKey(userEmail)) {
                      final nameParts = nameController.text.trim().split(' ');
                      final firstName = nameParts.isNotEmpty ? nameParts.first : 'Cliente';
                      final pass = '${firstName}#2024'; // Seed dynamic temp pass
                      await HiveHelper.usersBox.put(userEmail, {
                        'email': userEmail,
                        'name': nameController.text.trim(),
                        'passwordHash': Sha256Helper.hash(pass),
                        'role': 'client',
                        'isActive': true,
                      });
                    }
                  }
                  setState(() {});
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _showClientProfileDialog(Map<String, dynamic> client) {
    final clientPolicies = HiveHelper.policiesBox.values
        .map((p) => Map<String, dynamic>.from(p))
        .where((p) => p['clientDoc'] == client['id'] && p['isDeleted'] != true)
        .toList();

    final activePolicies = clientPolicies.where((p) => p['status'] == 'activa').toList();
    final expiredPolicies = clientPolicies.where((p) => p['status'] != 'activa').toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Perfil de Cliente: ${client['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 550,
            height: 400,
            child: ListView(
              children: [
                _buildStaticRow('Cédula de Identidad', client['id']),
                _buildStaticRow('Teléfono de Contacto', client['phone']),
                _buildStaticRow('Correo electrónico', client['email']),
                const SizedBox(height: 16),
                const Text('PÓLIZAS ACTIVAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                const Divider(color: Colors.green),
                activePolicies.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('Sin pólizas activas.', style: TextStyle(fontStyle: FontStyle.italic)),
                      )
                    : Column(
                        children: activePolicies.map((p) {
                          return ListTile(
                            title: Text('${p['vehicleBrand']} ${p['vehicleModel']} (${p['plate']})'),
                            subtitle: Text('Póliza: ${p['number']} · Vence: ${p['endDate']}'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _showPolicyDetailsDialog(p);
                            },
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 16),
                const Text('PÓLIZAS VENCIDAS O CANCELADAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                const Divider(color: Colors.red),
                expiredPolicies.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('Sin pólizas vencidas.', style: TextStyle(fontStyle: FontStyle.italic)),
                      )
                    : Column(
                        children: expiredPolicies.map((p) {
                          return ListTile(
                            title: Text('${p['vehicleBrand']} ${p['vehicleModel']} (${p['plate']})'),
                            subtitle: Text('Póliza: ${p['number']} · Vence: ${p['endDate']} · Estado: ${p['status']}'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _showPolicyDetailsDialog(p);
                            },
                          );
                        }).toList(),
                      ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  // ============================================
  // TAB: USERS VIEW
  // ============================================
  Widget _buildUsersView() {
    final query = _searchController.text.trim().toLowerCase();
    
    final users = HiveHelper.usersBox.values
        .map((u) => Map<String, dynamic>.from(u))
        .toList();

    final filteredUsers = users.where((u) {
      final matchesSearch = u['name'].toString().toLowerCase().contains(query) ||
          u['email'].toString().toLowerCase().contains(query);
      return matchesSearch;
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Buscar usuarios por nombre o correo...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  onPressed: () => _showUserFormDialog(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Crear Usuario'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: filteredUsers.isEmpty
                  ? const Center(child: Text('No se encontraron usuarios.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(AppTheme.lightBg),
                        columns: const [
                          DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Correo electrónico', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Rol', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filteredUsers.map((u) {
                          return DataRow(cells: [
                            DataCell(Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(u['email'])),
                            DataCell(Text(u['role'])),
                            DataCell(Text(u['isActive'] == true ? 'Activo' : 'Inactivo')),
                            DataCell(IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              tooltip: 'Editar',
                              onPressed: () => _showUserFormDialog(user: u),
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

  void _showUserFormDialog({Map<String, dynamic>? user}) {
    final isEditing = user != null;
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: isEditing ? user['name'] : '');
    final emailController = TextEditingController(text: isEditing ? user['email'] : '');
    final passController = TextEditingController();

    String role = isEditing ? user['role'] : 'admin_rjseguros';
    bool isActive = isEditing ? user['isActive'] : true;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Cuenta de Usuario' : 'Crear Cuenta de Usuario',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: AppTheme.textDark),
                    decoration: const InputDecoration(labelText: 'Nombre Completo'),
                    validator: (v) => v!.trim().isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    enabled: !isEditing,
                    style: const TextStyle(color: AppTheme.textDark),
                    decoration: const InputDecoration(labelText: 'Correo electrónico'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Correo obligatorio';
                      if (!isEditing && HiveHelper.usersBox.containsKey(v.trim().toLowerCase())) {
                        return 'Este correo ya se encuentra registrado';
                      }
                      return null;
                    },
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passController,
                      style: const TextStyle(color: AppTheme.textDark),
                      decoration: const InputDecoration(labelText: 'Contraseña Temporal'),
                      validator: (v) => v!.isEmpty ? 'Contraseña obligatoria' : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Rol de Acceso'),
                    items: const [
                      DropdownMenuItem(value: 'admin_system', child: Text('Administrador del Sistema')),
                      DropdownMenuItem(value: 'admin_rjseguros', child: Text('Administrador RJ Seguros')),
                      DropdownMenuItem(value: 'client', child: Text('Cliente Asegurado')),
                    ],
                    onChanged: (v) => role = v!,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Cuenta Activa'),
                    value: isActive,
                    onChanged: (v) => isActive = v,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final emailKey = emailController.text.trim().toLowerCase();
                  if (isEditing) {
                    final updatedUser = {
                      ...user,
                      'name': nameController.text.trim(),
                      'role': role,
                      'isActive': isActive,
                    };
                    await HiveHelper.usersBox.put(emailKey, updatedUser);
                  } else {
                    final newUser = {
                      'email': emailKey,
                      'name': nameController.text.trim(),
                      'passwordHash': Sha256Helper.hash(passController.text),
                      'role': role,
                      'isActive': isActive,
                    };
                    await HiveHelper.usersBox.put(emailKey, newUser);
                  }
                  setState(() {});
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // ============================================
  // TAB: OCR VIEW
  // ============================================
  Widget _buildOcrView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: Control / upload simulation
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Simular Carga de Documento Póliza',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text(
                    'Seleccione una de las siguientes pólizas de demostración para simular la digitalización y extracción por procesamiento de texto OCR local:',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildOcrOptionCard(
                    title: 'Póliza Toyota Corolla - Liviano',
                    subtitle: 'Toyota Corolla 2020 blanco (placa GPA-1234)',
                    mockId: 'toyota_corolla',
                  ),
                  const SizedBox(height: 12),
                  _buildOcrOptionCard(
                    title: 'Póliza Camión Hino - Pesado',
                    subtitle: 'Hino 300 2019 amarillo (placa GPC-9012)',
                    mockId: 'hino_truck',
                  ),
                  const SizedBox(height: 12),
                  _buildOcrOptionCard(
                    title: 'Documento Manchado / Ilegible',
                    subtitle: 'Simula un fallo parcial o total en reconocimiento',
                    mockId: 'illegible_scan',
                  ),
                  const Spacer(),
                  if (_ocrExtractedData != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                      onPressed: _saveOcrExtractedPolicy,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Confirmar y Guardar en Sistema'),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 48, thickness: 1, color: AppTheme.borderLight),
            
            // Right: Extraction results form
            Expanded(
              flex: 2,
              child: _ocrExtractedData == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.document_scanner, size: 64, color: AppTheme.textMuted),
                          SizedBox(height: 16),
                          Text('Ningún documento procesado.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
                        ],
                      ),
                    )
                  : _buildOcrForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrOptionCard({required String title, required String subtitle, required String mockId}) {
    final isSelected = _selectedOcrMock == mockId;
    return InkWell(
      onTap: () => _processOcrMock(mockId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderLight,
            width: isSelected ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.03) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _processOcrMock(String mockId) {
    setState(() {
      _selectedOcrMock = mockId;
      
      if (mockId == 'toyota_corolla') {
        _ocrExtractedData = {
          'number': 'POL-VL-2026-999',
          'clientDoc': '0912345678',
          'clientName': 'Carlos Eduardo Pérez Morales',
          'clientEmail': 'c.perez@gmail.com',
          'vehicleBrand': 'Toyota',
          'vehicleModel': 'Corolla',
          'vehicleYear': '2020',
          'vehicleColor': 'Blanco',
          'plate': 'GPA-1234',
          'type': 'liviano',
          'value': '18500.00',
          'prima': '52.30',
          'startDate': '2026-06-01',
          'endDate': '2027-06-01',
          'tonnage': '0.0',
          'coverages': ['Daños propios', 'Responsabilidad civil'],
        };
        _ocrConfidence = {
          'number': 'high',
          'clientDoc': 'high',
          'vehicleBrand': 'high',
          'vehicleModel': 'high',
          'plate': 'high',
          'startDate': 'low',
          'endDate': 'low',
          'value': 'high',
          'prima': 'high',
        };
      } else if (mockId == 'hino_truck') {
        _ocrExtractedData = {
          'number': 'POL-VP-2026-777',
          'clientDoc': '0934567890',
          'clientName': 'Roberto Antonio Vega Cruz',
          'clientEmail': 'r.vega@gmail.com',
          'vehicleBrand': 'Hino',
          'vehicleModel': '300',
          'vehicleYear': '2019',
          'vehicleColor': 'Amarillo',
          'plate': 'GPC-9012',
          'type': 'pesado',
          'value': '42000.00',
          'prima': '185.00',
          'startDate': '2026-06-20',
          'endDate': '2027-06-20',
          'tonnage': '', // Failed to extract tonnage
          'coverages': ['Daños propios', 'Responsabilidad civil ampliada'],
        };
        _ocrConfidence = {
          'number': 'high',
          'clientDoc': 'high',
          'vehicleBrand': 'high',
          'vehicleModel': 'high',
          'plate': 'high',
          'startDate': 'high',
          'endDate': 'high',
          'value': 'high',
          'prima': 'high',
          'tonnage': 'none',
        };
      } else if (mockId == 'illegible_scan') {
        _ocrExtractedData = {
          'number': '',
          'clientDoc': '',
          'clientName': '',
          'clientEmail': '',
          'vehicleBrand': '',
          'vehicleModel': '',
          'vehicleYear': '',
          'vehicleColor': '',
          'plate': '',
          'type': 'liviano',
          'value': '',
          'prima': '',
          'startDate': '',
          'endDate': '',
          'tonnage': '',
          'coverages': [],
        };
        _ocrConfidence = {
          'number': 'none',
          'clientDoc': 'none',
          'vehicleBrand': 'none',
          'vehicleModel': 'none',
          'plate': 'none',
          'startDate': 'none',
          'endDate': 'none',
          'value': 'none',
          'prima': 'none',
        };
      }
    });
  }

  Widget _buildOcrForm() {
    final missingFields = <String>[];
    _ocrExtractedData!.forEach((key, val) {
      if (val == null || val.toString().trim().isEmpty) {
        if (key != 'tonnage' || _ocrExtractedData!['type'] == 'pesado') {
          missingFields.add(key);
        }
      }
    });

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fields form
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Verificación y Revisión de Datos Extraídos',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                
                _buildOcrInputField('Nro. Póliza', 'number'),
                const SizedBox(height: 12),
                
                // Client dropdown/selector simulation for convenience
                DropdownButtonFormField<String>(
                  value: _ocrExtractedData!['clientDoc'].toString().isEmpty
                      ? null
                      : _ocrExtractedData!['clientDoc'],
                  decoration: _getOcrInputDecoration('Asegurado', 'clientDoc'),
                  items: HiveHelper.clientsBox.values.map((c) {
                    final clientMap = Map<String, dynamic>.from(c);
                    return DropdownMenuItem(
                      value: clientMap['id'].toString(),
                      child: Text('${clientMap['name']} (${clientMap['id']})'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    final clientMap = Map<String, dynamic>.from(HiveHelper.clientsBox.get(v));
                    setState(() {
                      _ocrExtractedData!['clientDoc'] = clientMap['id'];
                      _ocrExtractedData!['clientName'] = clientMap['name'];
                      _ocrExtractedData!['clientEmail'] = clientMap['email'];
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _ocrExtractedData!['type'],
                        decoration: const InputDecoration(labelText: 'Tipo de Vehículo'),
                        items: const [
                          DropdownMenuItem(value: 'liviano', child: Text('Vehículo Liviano')),
                          DropdownMenuItem(value: 'pesado', child: Text('Vehículo Pesado')),
                        ],
                        onChanged: (v) => setState(() => _ocrExtractedData!['type'] = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildOcrInputField('Placa', 'plate')),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(child: _buildOcrInputField('Marca', 'vehicleBrand')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildOcrInputField('Modelo', 'vehicleModel')),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(child: _buildOcrInputField('Año', 'vehicleYear')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildOcrInputField('Color', 'vehicleColor')),
                  ],
                ),
                const SizedBox(height: 12),
                
                if (_ocrExtractedData!['type'] == 'pesado') ...[
                  _buildOcrInputField('Tonelaje', 'tonnage'),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Expanded(child: _buildOcrInputField('Valor Asegurado', 'value')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildOcrInputField('Prima Mensual', 'prima')),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(child: _buildOcrInputField('Inicio Vigencia', 'startDate')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildOcrInputField('Fin Vigencia', 'endDate')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        
        // Sidebar showing missing/low confidence fields
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.lightBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Campos Pendientes / Alertas',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 8),
                const Text('Campos vacíos o identificados con baja confianza:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 16),
                
                if (missingFields.isEmpty &&
                    !_ocrConfidence.values.contains('low'))
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text('¡Datos listos con alta confianza!',
                          style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  )
                else ...[
                  ..._ocrConfidence.keys.map((k) {
                    final conf = _ocrConfidence[k];
                    final val = _ocrExtractedData![k];
                    
                    if (conf == 'high') return const SizedBox();
                    
                    String label = _getOcrLabel(k);
                    bool isEmpty = val == null || val.toString().isEmpty;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: isEmpty ? Colors.red.shade50 : Colors.amber.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(
                              isEmpty ? Icons.error_outline : Icons.warning_amber_outlined,
                              color: isEmpty ? AppTheme.errorColor : AppTheme.warningColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(
                                    isEmpty ? 'No se pudo extraer del archivo' : 'Extracción dudosa/parcial',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getOcrLabel(String key) {
    switch (key) {
      case 'number':
        return 'Nro. Póliza';
      case 'clientDoc':
        return 'Asegurado (Cédula)';
      case 'plate':
        return 'Placa';
      case 'vehicleBrand':
        return 'Marca';
      case 'vehicleModel':
        return 'Modelo';
      case 'vehicleYear':
        return 'Año';
      case 'vehicleColor':
        return 'Color';
      case 'value':
        return 'Valor Asegurado';
      case 'prima':
        return 'Prima';
      case 'startDate':
        return 'Inicio Vigencia';
      case 'endDate':
        return 'Fin Vigencia';
      case 'tonnage':
        return 'Tonelaje';
      default:
        return key;
    }
  }

  Widget _buildOcrInputField(String label, String key) {
    final conf = _ocrConfidence[key] ?? 'high';
    final val = _ocrExtractedData![key];

    return TextFormField(
      initialValue: val,
      style: const TextStyle(color: AppTheme.textDark),
      decoration: _getOcrInputDecoration(label, key),
      onChanged: (newVal) {
        setState(() {
          _ocrExtractedData![key] = newVal;
          if (newVal.isNotEmpty) {
            _ocrConfidence[key] = 'high'; // Clear low confidence on user input
          }
        });
      },
    );
  }

  InputDecoration _getOcrInputDecoration(String label, String key) {
    final conf = _ocrConfidence[key] ?? 'high';
    final val = _ocrExtractedData![key];
    final isEmpty = val == null || val.toString().isEmpty;

    Color labelColor = AppTheme.textMuted;
    Color borderCol = AppTheme.borderLight;
    
    if (isEmpty) {
      borderCol = AppTheme.errorColor;
      labelColor = AppTheme.errorColor;
    } else if (conf == 'low') {
      borderCol = AppTheme.warningColor;
      labelColor = AppTheme.warningColor;
    }

    return InputDecoration(
      labelText: '$label (${isEmpty ? "Pendiente" : conf == "low" ? "Confianza Baja" : "Confianza Alta"})',
      labelStyle: TextStyle(color: labelColor, fontSize: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderCol, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isEmpty ? AppTheme.errorColor : conf == 'low' ? AppTheme.warningColor : AppTheme.primaryColor, width: 2),
      ),
    );
  }

  void _saveOcrExtractedPolicy() async {
    final data = _ocrExtractedData!;
    
    // Check validation of fields
    if (data['number'].toString().isEmpty ||
        data['clientDoc'].toString().isEmpty ||
        data['plate'].toString().isEmpty ||
        data['vehicleBrand'].toString().isEmpty ||
        data['vehicleModel'].toString().isEmpty ||
        data['value'].toString().isEmpty ||
        data['prima'].toString().isEmpty ||
        data['startDate'].toString().isEmpty ||
        data['endDate'].toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor complete todos los campos obligatorios antes de guardar.')),
      );
      return;
    }

    final double value = double.tryParse(data['value']) ?? 0.0;
    final double prima = double.tryParse(data['prima']) ?? 0.0;
    final int year = int.tryParse(data['vehicleYear']) ?? 2026;
    final double tonnage = double.tryParse(data['tonnage'] ?? '0.0') ?? 0.0;

    final newPol = {
      'number': data['number'],
      'clientDoc': data['clientDoc'],
      'clientName': data['clientName'],
      'clientEmail': data['clientEmail'],
      'vehicleBrand': data['vehicleBrand'],
      'vehicleModel': data['vehicleModel'],
      'vehicleYear': year,
      'vehicleColor': data['vehicleColor'],
      'plate': data['plate'].toString().toUpperCase(),
      'type': data['type'],
      'coverages': data['coverages'],
      'value': value,
      'prima': prima,
      'startDate': data['startDate'],
      'endDate': data['endDate'],
      'status': 'activa',
      'tonnage': tonnage,
      'isDeleted': false,
      'changesHistory': [],
      'attachments': [],
      'paymentStatus': 'Al día',
      'lastPaymentDate': data['startDate'],
    };

    await HiveHelper.policiesBox.put(data['number'], newPol);
    NotificationsManager.schedulePolicyNotifications(newPol);

    setState(() {
      _selectedOcrMock = null;
      _ocrExtractedData = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Póliza Nro. ${newPol['number']} extraída e integrada con éxito.')),
    );
  }

  // ============================================
  // TAB: REPORTS VIEW
  // ============================================
  Widget _buildReportsView() {
    final allPolicies = HiveHelper.policiesBox.values
        .map((p) => Map<String, dynamic>.from(p))
        .where((p) => p['isDeleted'] != true)
        .toList();

    // 1. Distribution totals
    final totalCount = allPolicies.length;
    final lightCount = allPolicies.where((p) => p['type'] == 'liviano').length;
    final heavyCount = allPolicies.where((p) => p['type'] == 'pesado').length;

    final double lightPct = totalCount > 0 ? (lightCount / totalCount) * 100 : 0.0;
    final double heavyPct = totalCount > 0 ? (heavyCount / totalCount) * 100 : 0.0;

    // 2. Production in dates
    final filteredByDates = allPolicies.where((p) {
      try {
        final start = DateTime.parse(p['startDate']);
        return start.isAfter(_reportStartDate) && start.isBefore(_reportEndDate);
      } catch (_) {
        return false;
      }
    }).toList();

    final createdCount = filteredByDates.length;
    final activeInPeriod = filteredByDates.where((p) => p['status'] == 'activa').length;
    final expiredInPeriod = filteredByDates.where((p) => p['status'] == 'vencida').length;

    // 3. System change logs
    final changeLogs = <Map<String, dynamic>>[];
    for (var p in allPolicies) {
      final logs = p['changesHistory'] as List?;
      if (logs != null) {
        for (var l in logs) {
          changeLogs.add({
            'policy': p['number'],
            'client': p['clientName'],
            ...Map<String, dynamic>.from(l),
          });
        }
      }
    }
    // Sort logs descending by date
    changeLogs.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Export Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Reportes de Gestión del Portafolio',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ElevatedButton.icon(
                    onPressed: _triggerPrint,
                    icon: const Icon(Icons.print, color: Colors.white),
                    label: const Text('Exportar Reporte (PDF/Impresión)'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Grid Row 1: KPI Stats
              Row(
                children: [
                  Expanded(
                    child: _buildReportKpiCard(
                      title: 'Distribución de Portafolio',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildReportStatRow('Vehículos Livianos', '$lightCount ($lightPct%)'),
                          _buildReportStatRow('Vehículos Pesados', '$heavyCount ($heavyPct%)'),
                          _buildReportStatRow('Total Registrados', '$totalCount pólizas'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildReportKpiCard(
                      title: 'Producción y Crecimiento',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildReportStatRow('Pólizas Emitidas', '$createdCount'),
                          _buildReportStatRow('Estado Activas', '$activeInPeriod'),
                          _buildReportStatRow('Vencidas en Período', '$expiredInPeriod'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Log History table
              const Text('Bitácora de Modificaciones a Pólizas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              changeLogs.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Text('No hay modificaciones registradas en las pólizas en esta sesión.'),
                      ),
                    )
                  : Table(
                      border: TableBorder.all(color: AppTheme.borderLight, width: 1),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(1.5),
                        5: FlexColumnWidth(1.5),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: AppTheme.lightBg),
                          children: const [
                            Padding(padding: EdgeInsets.all(10), child: Text('Fecha y Hora', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Póliza Nro.', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Asegurado', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Campo', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Valor Anterior', style: TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Valor Nuevo', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                        ...changeLogs.take(15).map((log) {
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text(log['date'])),
                              Padding(padding: const EdgeInsets.all(10), child: Text(log['policy'], style: const TextStyle(fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(log['client'])),
                              Padding(padding: const EdgeInsets.all(10), child: Text(log['field'])),
                              Padding(padding: const EdgeInsets.all(10), child: Text(log['oldValue'], style: const TextStyle(color: AppTheme.errorColor))),
                              Padding(padding: const EdgeInsets.all(10), child: Text(log['newValue'], style: const TextStyle(color: AppTheme.successColor))),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportKpiCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.lightBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildReportStatRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ============================================
  // TAB: ALERTS VIEW
  // ============================================
  Widget _buildAlertsView() {
    final allPolicies = HiveHelper.policiesBox.values
        .map((p) => Map<String, dynamic>.from(p))
        .where((p) => p['isDeleted'] != true && p['status'] == 'activa')
        .toList();

    int _calculateDaysLeft(String endDateStr) {
      try {
        final endDate = DateTime.parse(endDateStr);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final expiry = DateTime(endDate.year, endDate.month, endDate.day);
        return expiry.difference(today).inDays;
      } catch (_) {
        return 0;
      }
    }

    final alertedPolicies = allPolicies.where((p) {
      final days = _calculateDaysLeft(p['endDate']);
      return days > 0 && days <= _alertDaysThreshold.toInt();
    }).toList();

    alertedPolicies.sort((a, b) => _calculateDaysLeft(a['endDate']).compareTo(_calculateDaysLeft(b['endDate'])));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Configurations slider
            Row(
              children: [
                const Text('Filtrar vencimientos próximos: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                DropdownButton<double>(
                  value: _alertDaysThreshold,
                  onChanged: (v) => setState(() => _alertDaysThreshold = v!),
                  items: const [
                    DropdownMenuItem(value: 30.0, child: Text('Dentro de 30 días')),
                    DropdownMenuItem(value: 60.0, child: Text('Dentro de 60 días')),
                    DropdownMenuItem(value: 90.0, child: Text('Dentro de 90 días')),
                  ],
                ),
                const Spacer(),
                Text('${alertedPolicies.length} Póliza(s) encontradas',
                    style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: alertedPolicies.isEmpty
                  ? const Center(child: Text('No hay pólizas próximas a vencer bajo el rango seleccionado.'))
                  : ListView.builder(
                      itemCount: alertedPolicies.length,
                      itemBuilder: (context, index) {
                        final p = alertedPolicies[index];
                        final days = _calculateDaysLeft(p['endDate']);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: days <= 15 ? Colors.red.shade50 : Colors.amber.shade50,
                          child: ListTile(
                            leading: Icon(
                              days <= 15 ? Icons.alarm_on : Icons.alarm,
                              color: days <= 15 ? AppTheme.errorColor : AppTheme.warningColor,
                            ),
                            title: Text('Póliza: ${p['number']} · Placa: ${p['plate']}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Cliente: ${p['clientName']} · Vence: ${p['endDate']} (${p['clientEmail']})'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: days <= 15 ? AppTheme.errorColor : AppTheme.warningColor),
                              ),
                              child: Text(
                                'Faltan $days días',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: days <= 15 ? AppTheme.errorColor : AppTheme.warningColor,
                                ),
                              ),
                            ),
                            onTap: () => _showPolicyDetailsDialog(p),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
