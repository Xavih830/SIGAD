import 'package:flutter/material.dart';
import 'package:sigad/core/theme/app_theme.dart';

class OcrRawTextPreview extends StatelessWidget {
  final String text;

  const OcrRawTextPreview({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Texto Completo Reconocido:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: AppTheme.borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', height: 1.3),
          ),
        ),
      ],
    );
  }
}
