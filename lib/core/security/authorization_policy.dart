import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/security/app_capability.dart';

abstract class AuthorizationPolicy {
  static const Map<UserRole, Set<AppCapability>> _roleCapabilities = {
    UserRole.admin: {
      AppCapability.viewPolicies,
      AppCapability.createPolicy,
      AppCapability.viewClients,
      AppCapability.createClient,
      AppCapability.scanOcr,
      AppCapability.manageOcrSchemas,
      AppCapability.manageCatalogs,
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

  static bool hasCapability(UserRole role, AppCapability capability) {
    return _roleCapabilities[role]?.contains(capability) ?? false;
  }

  static bool canUser(UserModel user, AppCapability capability) {
    return hasCapability(user.role, capability);
  }

  static bool canUserAny(UserModel user, Iterable<AppCapability> capabilities) {
    return capabilities.any((cap) => canUser(user, cap));
  }
}
