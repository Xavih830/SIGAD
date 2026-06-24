import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/hive_helper.dart';
import '../../../../core/services/notifications_manager.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/pages/login_page.dart';
import 'policy_detail_page.dart';

class MobileDashboardPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const MobileDashboardPage({super.key, required this.user});

  @override
  State<MobileDashboardPage> createState() => _MobileDashboardPageState();
}

class _MobileDashboardPageState extends State<MobileDashboardPage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Trigger welcome notification if first session
    NotificationsManager.showWelcomeNotification(widget.user['email']);
  }

  // Get current client's policies from Hive
  List<Map<String, dynamic>> _getClientPolicies() {
    final email = widget.user['email'] as String;
    final allPolicies = HiveHelper.policiesBox.values
        .map((p) => Map<String, dynamic>.from(p))
        .where((p) => p['clientEmail'] == email && p['isDeleted'] != true)
        .toList();

    // Sort: Active policies first, then sort by days remaining ascending
    allPolicies.sort((a, b) {
      final aActive = a['status'] == 'activa' ? 1 : 0;
      final bActive = b['status'] == 'activa' ? 1 : 0;
      if (aActive != bActive) {
        return bActive.compareTo(aActive);
      }
      final aDays = _calculateDaysLeft(a['endDate']);
      final bDays = _calculateDaysLeft(b['endDate']);
      return aDays.compareTo(bDays);
    });

    return allPolicies;
  }

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

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+|-'), '');
    final url = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar la llamada al $phone')),
        );
      }
    }
  }

  Future<void> _sendMail(String email) async {
    final url = Uri.parse('mailto:$email?subject=Consulta SIGAD');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el cliente de correo para $email')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final policies = _getClientPolicies();
    final activePoliciesCount = policies.where((p) => p['status'] == 'activa').length;

    final tabs = [
      _buildPoliciesTab(policies, activePoliciesCount),
      _buildAssistanceTab(),
      _buildWorkshopsTab(),
      _buildContactTab(),
    ];

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
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Text(
                _currentIndex == 0
                    ? 'Mis Pólizas'
                    : _currentIndex == 1
                        ? 'Asistencias'
                        : _currentIndex == 2
                            ? 'Talleres Autorizados'
                            : 'Contacto',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Cerrar Sesión',
              onPressed: () {
                context.read<AuthBloc>().add(LogoutRequested());
              },
            ),
          ],
        ),
        body: SafeArea(
          child: tabs[_currentIndex],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.textMuted,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              activeIcon: Icon(Icons.description),
              label: 'Pólizas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_phone_outlined),
              activeIcon: Icon(Icons.local_phone),
              label: 'Asistencia',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.build_outlined),
              activeIcon: Icon(Icons.build),
              label: 'Talleres',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              activeIcon: Icon(Icons.business),
              label: 'Contacto',
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: Policies list view
  Widget _buildPoliciesTab(List<Map<String, dynamic>> policies, int activeCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Welcoming banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${widget.user['name']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tienes $activeCount póliza(s) vehicular(es) activa(s).',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: policies.isEmpty
                ? const Center(
                    child: Text(
                      'No tienes pólizas registradas.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: policies.length,
                    itemBuilder: (context, index) {
                      final p = policies[index];
                      final daysLeft = _calculateDaysLeft(p['endDate']);
                      final isSoonExpiring = daysLeft > 0 && daysLeft <= 30;
                      final isExpired = daysLeft <= 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PolicyDetailPage(
                                  policy: p,
                                  onReportError: () {
                                    setState(() {
                                      _currentIndex = 3; // Redirect to contact
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: p['type'] == 'pesado'
                                            ? Colors.orange.shade50
                                            : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        p['type'] == 'pesado'
                                            ? 'Vehículo Pesado'
                                            : 'Vehículo Liviano',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: p['type'] == 'pesado'
                                              ? Colors.orange.shade800
                                              : AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isExpired
                                            ? AppTheme.errorColor.withOpacity(0.1)
                                            : AppTheme.successColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isExpired ? 'Vencida' : 'Activa',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isExpired ? AppTheme.errorColor : AppTheme.successColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${p['vehicleBrand']} ${p['vehicleModel']} (${p['vehicleYear']})',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Placa: ${p['plate']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Divider(color: AppTheme.borderLight, height: 1),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Nº de Póliza',
                                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                        ),
                                        Text(
                                          p['number'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Vencimiento',
                                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                        ),
                                        Text(
                                          p['endDate'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (isSoonExpiring) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warningColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded,
                                            color: AppTheme.warningColor, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Alerta: Vence en $daysLeft días.',
                                            style: const TextStyle(
                                              color: AppTheme.textDark,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 2: Emergency assistance phone list
  Widget _buildAssistanceTab() {
    final assistanceItems = HiveHelper.assistanceBox.values.toList();

    IconData _getIcon(String iconName) {
      switch (iconName) {
        case 'local_shipping':
          return Icons.local_shipping;
        case 'build':
          return Icons.build;
        case 'explore':
          return Icons.explore;
        case 'emergency':
          return Icons.emergency;
        default:
          return Icons.phone;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Números de Emergencia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Presiona sobre cualquiera de los servicios para llamar inmediatamente.',
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: assistanceItems.length,
              itemBuilder: (context, index) {
                final item = Map<String, dynamic>.from(assistanceItems[index]);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getIcon(item['icon']), color: AppTheme.errorColor, size: 28),
                    ),
                    title: Text(
                      item['type'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      item['phone'],
                      style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                    ),
                    trailing: const Icon(Icons.phone_in_talk, color: AppTheme.primaryColor),
                    onTap: () => _makeCall(item['phone']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: Authorized workshops list
  Widget _buildWorkshopsTab() {
    final workshops = HiveHelper.workshopsBox.values.toList();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Red de Talleres Autorizados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Talleres predefinidos para la atención mecánica de siniestros.',
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: workshops.length,
              itemBuilder: (context, index) {
                final w = Map<String, dynamic>.from(workshops[index]);
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.build_circle, color: AppTheme.primaryColor, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Especialidad: ${w['specialty']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: AppTheme.borderLight, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                w['address'],
                                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _makeCall(w['phone']),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.phone_android_outlined, size: 16, color: AppTheme.textMuted),
                                const SizedBox(width: 8),
                                Text(
                                  w['phone'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.open_in_new, size: 12, color: AppTheme.primaryColor),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // TAB 4: Broker Contact & Info
  Widget _buildContactTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Color(0xFFE7F5FF),
              child: Icon(Icons.business, color: AppTheme.primaryColor, size: 48),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'RJ Seguros',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Corredora de Seguros Vehiculares',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          // Details Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildContactRow(
                    icon: Icons.phone,
                    title: 'Llámanos',
                    value: '04-2987654',
                    onTap: () => _makeCall('04-2987654'),
                  ),
                  const Divider(color: AppTheme.borderLight, height: 24),
                  _buildContactRow(
                    icon: Icons.email,
                    title: 'Escríbenos',
                    value: 'contacto@rjseguros.ec',
                    onTap: () => _sendMail('contacto@rjseguros.ec'),
                  ),
                  const Divider(color: AppTheme.borderLight, height: 24),
                  _buildContactRow(
                    icon: Icons.schedule,
                    title: 'Horario de Atención',
                    value: 'Lunes a Viernes de 09:00 a 18:00',
                    onTap: null,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar Sesión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: onTap != null ? AppTheme.primaryColor : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
