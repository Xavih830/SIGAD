import 'package:flutter/material.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/sigad_logo.dart';

class DashboardSidebar extends StatelessWidget {
  final String activeTab;
  final bool isSystemAdmin;
  final String userName;
  final String userRole;
  final ValueChanged<String> onTabSelected;
  final VoidCallback onLogout;

  const DashboardSidebar({
    super.key,
    required this.activeTab,
    required this.isSystemAdmin,
    required this.userName,
    required this.userRole,
    required this.onTabSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF111827),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                const SigadLogo(size: 38, showLabel: false),
                const SizedBox(width: 12),
                Text('SIGAD Web', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _item(Icons.description_outlined, 'Pólizas Vehiculares', 'policies'),
                  _item(Icons.people_outline, 'Clientes', 'clients'),
                  if (isSystemAdmin) _item(Icons.admin_panel_settings_outlined, 'Usuarios del Sistema', 'users'),
                  _item(Icons.document_scanner_outlined, 'Lector Documental OCR', 'ocr'),
                  _item(Icons.analytics_outlined, 'Reportes y Estadísticas', 'reports'),
                  _item(Icons.notification_important_outlined, 'Alertas de Vencimiento', 'alerts'),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const CircleAvatar(radius: 18, backgroundColor: AppTheme.primaryColor, child: Icon(Icons.person, color: Colors.white, size: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                      Text(userRole == 'admin_system' ? 'Sys Admin' : 'Admin RJ', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.logout, color: Colors.white60, size: 20), tooltip: 'Cerrar Sesión', onPressed: onLogout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String title, String tabId) {
    final isSelected = activeTab == tabId;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 20),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          onTap: () => onTabSelected(tabId),
        ),
      ),
    );
  }
}

