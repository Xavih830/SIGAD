import 'package:flutter/material.dart';
import 'package:sigad/core/theme/app_theme.dart';

class OcrStatusBadge extends StatelessWidget {
  final String estado;

  const OcrStatusBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    Color color = AppTheme.textMuted;
    switch (estado.toLowerCase()) {
      case 'completado':
        color = AppTheme.successColor;
        break;
      case 'procesando':
      case 'pendiente':
        color = AppTheme.warningColor;
        break;
      case 'revision_requerida':
        color = Colors.indigo;
        break;
      case 'error':
      case 'fallido':
      case 'error_permanente':
        color = AppTheme.errorColor;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class OcrConfidenceBadge extends StatelessWidget {
  final double? confianza;

  const OcrConfidenceBadge({super.key, required this.confianza});

  @override
  Widget build(BuildContext context) {
    if (confianza == null) return const SizedBox.shrink();
    final c = confianza!;
    final color = c < 60 ? AppTheme.errorColor : (c < 85 ? AppTheme.warningColor : AppTheme.successColor);
    final nivel = c < 60 ? 'BAJA' : (c < 85 ? 'MEDIA' : 'ALTA');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        'CONFIANZA $nivel (${c.toStringAsFixed(1)}%)',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class OcrPendingBanner extends StatelessWidget {
  final String estado;
  final VoidCallback onRefresh;

  const OcrPendingBanner({
    super.key,
    required this.estado,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Documento en estado "$estado". Se procesará en segundo plano.',
              style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
            ),
          ),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
}
