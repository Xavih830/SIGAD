import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/theme/app_theme.dart';

class PolicyDetailHeaderCard extends StatelessWidget {
  final PolicyModel policy;

  const PolicyDetailHeaderCard({
    super.key,
    required this.policy,
  });

  @override
  Widget build(BuildContext context) {
    final isExp = policy.isExpired;

    return Card(
      color: AppTheme.primaryColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PÓLIZA NRO',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              policy.number,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'VEHÍCULO ASEGURADO',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExp ? Colors.red.shade400 : Colors.green.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isExp ? 'VENCIDA' : 'ACTIVA',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
