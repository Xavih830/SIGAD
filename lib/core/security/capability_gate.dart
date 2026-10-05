import 'package:flutter/material.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/security/app_capability.dart';
import 'package:sigad/core/security/authorization_policy.dart';

/// Guardia declarativa de interfaz de usuario basada en capacidades.
/// Erradica el 'Tangling' de lógica de seguridad dentro de métodos build().
///
/// Si el [user] tiene la [capability], renderiza [child].
/// De lo contrario, renderiza [fallback] (por defecto un widget invisible).
class CapabilityGate extends StatelessWidget {
  final UserModel user;
  final AppCapability capability;
  final Widget child;
  final Widget? fallback;

  const CapabilityGate({
    super.key,
    required this.user,
    required this.capability,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final isAllowed = AuthorizationPolicy.canUser(user, capability);
    if (isAllowed) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
