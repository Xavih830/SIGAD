import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/auth/presentation/pages/login_page.dart';
import 'package:sigad/features/web_dashboard/domain/dashboard_tab_item.dart';
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
  late final List<DashboardTabItem> _permittedTabs;
  final Map<String, Widget> _instantiatedTabs = {};

  @override
  void initState() {
    super.initState();
    _permittedTabs = DashboardTabRegistry.getPermittedTabs(widget.user);
    if (_permittedTabs.isNotEmpty && !_permittedTabs.any((t) => t.id == _activeTab)) {
      _activeTab = _permittedTabs.first.id;
    }
    _ensureTabLoaded(_activeTab);
  }

  void _ensureTabLoaded(String tabId) {
    if (!_instantiatedTabs.containsKey(tabId)) {
      for (final tab in _permittedTabs) {
        if (tab.id == tabId) {
          _instantiatedTabs[tabId] = tab.builder();
          break;
        }
      }
    }
  }

  void _onTabSelected(String tabId) {
    setState(() {
      _activeTab = tabId;
      _ensureTabLoaded(tabId);
    });
  }

  Widget _tabContent() {
    if (_permittedTabs.isEmpty) {
      return const Center(
        child: Text(
          'Acceso Restringido: No dispone de permisos para acceder a esta consola.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    final activeIndex = _permittedTabs.indexWhere((t) => t.id == _activeTab);
    return IndexedStack(
      index: activeIndex >= 0 ? activeIndex : 0,
      children: _permittedTabs.map((tab) {
        return _instantiatedTabs[tab.id] ?? const SizedBox.shrink();
      }).toList(),
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
              onTabSelected: _onTabSelected,
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
