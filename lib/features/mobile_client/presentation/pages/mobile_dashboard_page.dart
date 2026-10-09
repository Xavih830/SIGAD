import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/services/notifications_manager.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/auth/presentation/pages/login_page.dart';
import 'package:sigad/features/mobile_client/presentation/tabs/mobile_assistance_tab.dart';
import 'package:sigad/features/mobile_client/presentation/tabs/mobile_contact_tab.dart';
import 'package:sigad/features/mobile_client/presentation/tabs/mobile_policies_tab.dart';
import 'package:sigad/features/mobile_client/presentation/tabs/mobile_workshops_tab.dart';

class MobileDashboardPage extends StatefulWidget {
  final UserModel user;
  const MobileDashboardPage({super.key, required this.user});

  @override
  State<MobileDashboardPage> createState() => _MobileDashboardPageState();
}

class _MobileDashboardPageState extends State<MobileDashboardPage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    NotificationsManager.showWelcomeNotification(widget.user.email);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Mis Pólizas', 'Asistencias', 'Talleres Autorizados', 'Contacto'];
    final tabs = [
      MobilePoliciesTab(user: widget.user, onNavigateToContact: () => setState(() => _currentIndex = 3)),
      const MobileAssistanceTab(),
      const MobileWorkshopsTab(),
      const MobileContactTab(),
    ];

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial || state is AuthFailure || state is AuthLockedOut) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titles[_currentIndex], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Cerrar Sesión',
              onPressed: () => context.read<AuthBloc>().add(LogoutRequested()),
            ),
          ],
        ),
        body: SafeArea(child: tabs[_currentIndex]),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.textMuted,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.description_outlined), activeIcon: Icon(Icons.description), label: 'Pólizas'),
            BottomNavigationBarItem(icon: Icon(Icons.local_phone_outlined), activeIcon: Icon(Icons.local_phone), label: 'Asistencia'),
            BottomNavigationBarItem(icon: Icon(Icons.build_outlined), activeIcon: Icon(Icons.build), label: 'Talleres'),
            BottomNavigationBarItem(icon: Icon(Icons.business_outlined), activeIcon: Icon(Icons.business), label: 'Contacto'),
          ],
        ),
      ),
    );
  }
}
