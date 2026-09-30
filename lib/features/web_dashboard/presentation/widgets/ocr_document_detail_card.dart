import 'package:flutter/material.dart';
import 'package:sigad/core/theme/app_theme.dart';

class OcrDocumentDetailCard extends StatelessWidget {
  final Map<String, dynamic>? document;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onLinkPolicy;

  const OcrDocumentDetailCard({
    super.key,
    required this.document,
    required this.isLoading,
    required this.onRefresh,
    required this.onLinkPolicy,
  });

  Widget _buildStatusBadge(String estado) {
    Color color = Colors.grey;
    switch (estado.toLowerCase()) {
      case 'completado': color = AppTheme.successColor; break;
      case 'procesando': color = AppTheme.accentColor; break;
      case 'pendiente': color = AppTheme.warningColor; break;
      case 'error': case 'error_permanente': color = AppTheme.errorColor; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.4))),
      child: Text(estado.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildConfidenceBadge(double? c) {
    if (c == null) return const SizedBox.shrink();
    final color = c < 60 ? AppTheme.errorColor : (c < 85 ? AppTheme.warningColor : AppTheme.successColor);
    final nivel = c < 60 ? 'BAJA' : (c < 85 ? 'MEDIA' : 'ALTA');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
      child: Text('CONFIANZA $nivel (${c.toStringAsFixed(1)}%)', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (document == null) return const Center(child: Text('Selecciona un documento o sube uno nuevo', style: TextStyle(color: AppTheme.textMuted)));
    if (isLoading) return const Center(child: CircularProgressIndicator());

    final doc = document!;
    final resultado = doc['resultado'] as Map<String, dynamic>?;
    final tamanoKb = ((doc['tamano_bytes'] as num? ?? 0) / 1024).toStringAsFixed(1);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc['nombre_archivo']?.toString() ?? 'Documento', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 4),
                    Text('ID: ${doc['id']?.toString().substring(0, 8)} • MIME: ${doc['tipo_mime']} • Tamaño: $tamanoKb KB', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              _buildStatusBadge(doc['estado_extraccion']?.toString() ?? ''),
            ],
          ),
          const SizedBox(height: 16),
          if (resultado != null) _buildResultContent(resultado) else _buildPendingBanner(doc['estado_extraccion']?.toString() ?? ''),
        ],
      ),
    );
  }

  Widget _buildPendingBanner(String estado) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(child: Text('Documento en estado "$estado". Se procesará en segundo plano.', style: const TextStyle(fontSize: 13, color: AppTheme.textDark))),
          TextButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Actualizar')),
        ],
      ),
    );
  }

  Widget _buildResultContent(Map<String, dynamic> res) {
    final metodo = res['metodo']?.toString() ?? 'desconocido';
    final confianza = (res['confianza'] as num?)?.toDouble();
    final campos = res['campos_extraidos'] as Map<String, dynamic>? ?? {};
    final texto = res['texto_completo']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Método: $metodo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            _buildConfidenceBadge(confianza),
          ],
        ),
        const Divider(height: 24, color: AppTheme.borderLight),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Campos Extraídos por el Pipeline:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              onPressed: onLinkPolicy,
              icon: const Icon(Icons.add_task, color: Colors.white, size: 18),
              label: const Text('Vincular como Póliza', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(2.5), 2: FlexColumnWidth(0.8)},
          children: [
            for (final entry in campos.entries)
              TableRow(
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.borderLight, width: 0.5))),
                children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(entry.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(entry.value?.toString() ?? 'No detectado', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: entry.value != null ? AppTheme.textDark : Colors.grey))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: entry.value != null ? const Icon(Icons.check_circle, size: 16, color: AppTheme.successColor) : const Icon(Icons.remove_circle_outline, size: 16, color: Colors.grey)),
                ],
              ),
          ],
        ),
        if (texto.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Texto Completo Reconocido:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: AppTheme.borderLight), borderRadius: BorderRadius.circular(8)),
            child: SelectableText(texto, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', height: 1.3)),
          ),
        ],
      ],
    );
  }
}
