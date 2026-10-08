/// Capacidades granulares de autorización en SIGAD (Capability-Based Access Control).
/// Permite verificar permisos específicos por acción o vista de forma declarativa.
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
