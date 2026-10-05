import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/security/authorization_policy.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/auth/presentation/pages/login_page.dart';
import 'package:sigad/features/web_dashboard/domain/dashboard_tab_registry.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/dashboard_header.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/dashboard_sidebar.dart';

class WebDashboardPage extends StatefulWidget {
  final UserModel user;
  const WebDashboardPage({super.key, required this.user});

  @override
  State<WebDashboardPage> createState() => _WebDashboardPageState();
}

class _WebDashboardPageState extends State<WebDashboardPage> {
  String _activeTab = 'policies';

  Widget _tabContent() {
    final tab = DashboardTabRegistry.findTabById(_activeTab);
    if (tab != null && AuthorizationPolicy.canUser(widget.user, tab.requiredCapability)) {
      return tab.builder();
    }
    final permitted = DashboardTabRegistry.getPermittedTabs(widget.user);
    if (permitted.isNotEmpty) {
      return permitted.first.builder();
    }
    return const Center(
      child: Text(
        'Acceso Restringido: No dispone de permisos para acceder a esta consola.',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: AppTheme.lightBg,
        body: Row(
          children: [
            DashboardSidebar(
              activeTab: _activeTab,
              user: widget.user,
              onTabSelected: (tab) => setState(() => _activeTab = tab),
              onLogout: () => context.read<AuthBloc>().add(LogoutRequested()),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DashboardHeader(activeTab: _activeTab),
                    const SizedBox(height: 20),
                    Expanded(child: _tabContent()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
