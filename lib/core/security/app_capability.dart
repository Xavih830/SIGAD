/// Capacidades granulares de autorización en SIGAD (Capability-Based Access Control).
/// Erradica el anti-patrón de 'Role Checking' disperso con 'if (user.role == ...)'
/// permitiendo verificar permisos específicos por acción o vista.
enum AppCapability {
  viewPolicies,
  createPolicy,
  viewClients,
  createClient,
  scanOcr,
  viewReports,
  viewAlerts,
  accessWebDashboard,
  accessMobileApp,
}
