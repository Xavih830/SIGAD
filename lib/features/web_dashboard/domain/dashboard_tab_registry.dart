import 'package:flutter/material.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/security/app_capability.dart';
import 'package:sigad/core/security/authorization_policy.dart';
import 'package:sigad/features/web_dashboard/domain/dashboard_tab_item.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/alerts_tab_view.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/clients_tab_view.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/ocr_schemas_tab_view.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/ocr_tab_view.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/policies_tab_view.dart';
import 'package:sigad/features/web_dashboard/presentation/tabs/reports_tab_view.dart';

abstract class DashboardTabRegistry {
  static final List<DashboardTabItem> allTabs = [
    DashboardTabItem(
      id: 'policies',
      title: 'Gestión de Pólizas Vehiculares',
      subtitle: 'Emisión, consulta y control de vigencias de pólizas.',
      icon: Icons.description_outlined,
      requiredCapability: AppCapability.viewPolicies,
      builder: () => const PoliciesTabView(),
    ),
    DashboardTabItem(
      id: 'clients',
      title: 'Directorio de Clientes',
      subtitle: 'Administración de titulares de pólizas aseguradas.',
      icon: Icons.people_outline,
      requiredCapability: AppCapability.viewClients,
      builder: () => const ClientsTabView(),
    ),
    DashboardTabItem(
      id: 'ocr',
      title: 'Lector Documental OCR',
      subtitle: 'Extracción automatizada de matrículas y cédulas de identidad.',
      icon: Icons.document_scanner_outlined,
      requiredCapability: AppCapability.scanOcr,
      builder: () => const OcrTabView(),
    ),
    DashboardTabItem(
      id: 'schemas',
      title: 'Esquemas de Extracción OCR',
      subtitle: 'Configuración y calibración de plantillas regex por aseguradora.',
      icon: Icons.rule_folder_outlined,
      requiredCapability: AppCapability.manageOcrSchemas,
      builder: () => const OcrSchemasTabView(),
    ),
    DashboardTabItem(
      id: 'reports',
      title: 'Reportes y Métricas Operativas',
      subtitle: 'Análisis de cartera asegurada y estimación de primas.',
      icon: Icons.analytics_outlined,
      requiredCapability: AppCapability.viewReports,
      builder: () => const ReportsTabView(),
    ),
    DashboardTabItem(
      id: 'alerts',
      title: 'Alertas de Vencimiento de Pólizas',
      subtitle: 'Monitoreo de pólizas próximas a caducar.',
      icon: Icons.notification_important_outlined,
      requiredCapability: AppCapability.viewAlerts,
      builder: () => const AlertsTabView(),
    ),
  ];

  static List<DashboardTabItem> getPermittedTabs(UserModel user) {
    return allTabs
        .where((tab) => AuthorizationPolicy.canUser(user, tab.requiredCapability))
        .toList();
  }

  static DashboardTabItem? findTabById(String id) {
    for (final tab in allTabs) {
      if (tab.id == id) return tab;
    }
    return null;
  }
}
