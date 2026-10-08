import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/security/app_capability.dart';

/// Fuente única canónica de autorización para el sistema SIGAD.
/// Centraliza la asignación de permisos según el modelo de capacidades (CBAC).
abstract class AuthorizationPolicy {
  static const Map<UserRole, Set<AppCapability>> _roleCapabilities = {
    UserRole.admin: {
      AppCapability.viewPolicies,
      AppCapability.createPolicy,
      AppCapability.viewClients,
      AppCapability.createClient,
      AppCapability.scanOcr,
      AppCapability.viewReports,
      AppCapability.viewAlerts,
      AppCapability.accessWebDashboard,
    },
    UserRole.agente: {
      AppCapability.viewPolicies,
      AppCapability.createPolicy,
      AppCapability.viewClients,
      AppCapability.createClient,
      AppCapability.scanOcr,
      AppCapability.viewAlerts,
      AppCapability.accessWebDashboard,
    },
    UserRole.cliente: {
      AppCapability.viewPolicies,
      AppCapability.accessMobileApp,
    },
  };

  /// Evalúa si un [UserRole] posee la [AppCapability] requerida.
  static bool hasCapability(UserRole role, AppCapability capability) {
    return _roleCapabilities[role]?.contains(capability) ?? false;
  }

  /// Evalúa si el usuario autenticado [UserModel] posee la [AppCapability] requerida.
  static bool canUser(UserModel user, AppCapability capability) {
    return hasCapability(user.role, capability);
  }

  /// Evalúa si el usuario autenticado [UserModel] posee al menos una de las capacidades.
  static bool canUserAny(UserModel user, Iterable<AppCapability> capabilities) {
    return capabilities.any((cap) => canUser(user, cap));
  }
}
