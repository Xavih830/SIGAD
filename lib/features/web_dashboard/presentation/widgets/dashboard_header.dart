import 'package:flutter/material.dart';
import 'package:sigad/core/theme/app_theme.dart';

class DashboardHeader extends StatelessWidget {
  final String activeTab;

  const DashboardHeader({super.key, required this.activeTab});

  String _title() {
    switch (activeTab) {
      case 'policies': return 'Gestión de Pólizas Vehiculares';
      case 'clients': return 'Directorio de Clientes';
      case 'users': return 'Usuarios y Roles del Sistema';
      case 'ocr': return 'Lector Documental OCR';
      case 'reports': return 'Reportes y Métricas Operativas';
      case 'alerts': return 'Alertas de Vencimiento de Pólizas';
      default: return 'Panel de Control';
    }
  }

  String _subtitle() {
    switch (activeTab) {
      case 'policies': return 'Emisión, consulta y control de vigencias de pólizas.';
      case 'clients': return 'Administración de titulares de pólizas aseguradas.';
      case 'users': return 'Gestión de credenciales y permisos administrativos.';
      case 'ocr': return 'Extracción automatizada de matrículas y cédulas de identidad.';
      case 'reports': return 'Análisis de cartera asegurada y estimación de primas.';
      case 'alerts': return 'Monitoreo de pólizas próximas a caducar.';
      default: return 'Sistema Integrado de Gestión Administrativa.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.textDark),
        ),
        const SizedBox(height: 4),
        Text(
          _subtitle(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
        ),
      ],
    );
  }
}
