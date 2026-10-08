/// Capacidades granulares de autorización en SIGAD (Capability-Based Access Control).
/// Permite verificar permisos específicos por acción o vista de forma declarativa.
enum AppCapability {
  viewPolicies,
  createPolicy,
  viewClients,
  createClient,
  scanOcr,
  manageOcrSchemas,
  manageCatalogs,
  viewReports,
  viewAlerts,
  accessWebDashboard,
  accessMobileApp,
}
