import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/auth/presentation/pages/login_page.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/alerts_tab_view.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/clients_tab_view.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/ocr_tab_view.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/policies_tab_view.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/reports_tab_view.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/users_tab_view.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/dashboard_header.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/dashboard_sidebar.dart';

class WebDashboardPage extends StatefulWidget {
  final UserModel user; //  UserModel en vez de Map<String, dynamic>
  const WebDashboardPage({super.key, required this.user});

  @override
  State<WebDashboardPage> createState() => _WebDashboardPageState();
}

class _WebDashboardPageState extends State<WebDashboardPage> {
  String _activeTab = 'policies';

  Widget _tabContent() {
    switch (_activeTab) {
      case 'policies': return const PoliciesTabView();
      case 'clients': return const ClientsTabView();
      case 'users': return const UsersTabView();
      case 'ocr': return const OcrTabView();
      case 'reports': return const ReportsTabView();
      case 'alerts': return const AlertsTabView();
      default: return const PoliciesTabView();
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user.role; // Acceso directo por propiedad tipada
    final isSysAdmin = role == 'admin_system';
    if (_activeTab == 'users' && !isSysAdmin) _activeTab = 'policies';

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
              isSystemAdmin: isSysAdmin,
              userName: widget.user.name,
              userRole: role,
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
