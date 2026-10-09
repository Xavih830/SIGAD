import 'package:flutter/material.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/security/app_capability.dart';
import 'package:sigad/core/security/authorization_policy.dart';

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
