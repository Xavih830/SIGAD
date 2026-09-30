import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sigad/core/theme/app_theme.dart';

class OtpWhatsAppDialog extends StatelessWidget {
  final String clientName;
  final String clientId;
  final String? clientEmail;
  final String otpCode;

  const OtpWhatsAppDialog({
    super.key,
    required this.clientName,
    required this.clientId,
    this.clientEmail,
    required this.otpCode,
  });

  @override
  Widget build(BuildContext context) {
    final message =
        'Hola $clientName, bienvenido a SIGAD RJ Seguros. '
        'Tu código de vinculación para activar tu aplicación móvil es: $otpCode. '
        'Este código es de uso personal y expira en 15 minutos.';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: AppTheme.primaryColor),
          SizedBox(width: 10),
          Text('Código de Vinculación OTP'),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cliente: $clientName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Cédula: $clientId', style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    'CÓDIGO DE 6 DÍGITOS',
                    style: TextStyle(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    otpCode,
                    style: const TextStyle(
                      fontSize: 36,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Vigencia: 15 minutos (HMAC-SHA256)', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (clientEmail != null && clientEmail!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Notificación de respaldo enviada a $clientEmail', style: const TextStyle(fontSize: 12, color: Colors.blue))),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(backgroundColor: Colors.green, content: Text('Mensaje copiado. Péguelo en el chat de WhatsApp.')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar mensaje para WhatsApp'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
      ],
    );
  }
}
