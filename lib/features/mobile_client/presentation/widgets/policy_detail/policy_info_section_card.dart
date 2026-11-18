import 'package:flutter/material.dart';
import 'package:sigad/core/theme/app_theme.dart';

class PolicyInfoRowData {
  final String label;
  final String value;
  final Color? color;

  const PolicyInfoRowData(this.label, this.value, {this.color});
}

class PolicyInfoSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<PolicyInfoRowData> rows;

  const PolicyInfoSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: rows.asMap().entries.map((e) {
                final row = e.value;
                return Column(
                  children: [
                    if (e.key > 0) const Divider(color: AppTheme.borderLight, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          row.label,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                        Text(
                          row.value,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: row.color ?? AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
