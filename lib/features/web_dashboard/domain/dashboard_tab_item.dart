import 'package:flutter/material.dart';
import 'package:sigad/core/security/app_capability.dart';

class DashboardTabItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final AppCapability requiredCapability;
  final Widget Function() builder;

  const DashboardTabItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.requiredCapability,
    required this.builder,
  });
}
