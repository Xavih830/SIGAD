import 'package:flutter/material.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/features/web_dashboard/domain/dashboard_tab_registry.dart';

class DashboardHeader extends StatelessWidget {
  final String activeTab;

  const DashboardHeader({super.key, required this.activeTab});

  @override
  Widget build(BuildContext context) {
    final tab = DashboardTabRegistry.findTabById(activeTab);
    final title = tab?.title ?? 'Panel de Control';
    final subtitle = tab?.subtitle ?? 'Sistema Integrado de Gestión Administrativa.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
        ),
      ],
    );
  }
}
