import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/theme/app_theme.dart';

class PolicyCoveragesSectionCard extends StatelessWidget {
  final List<CoverageModel> coverages;

  const PolicyCoveragesSectionCard({
    super.key,
    required this.coverages,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Row(
            children: [
              Icon(Icons.verified_user, color: AppTheme.primaryColor, size: 18),
              SizedBox(width: 8),
              Text(
                'Coberturas Contratadas',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: coverages
                  .map(
                    (cov) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cov.nombre,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
