import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/theme/app_theme.dart';

class BackendErrorBanner extends StatefulWidget {
  final String errorMessage;
  final VoidCallback? onRetry;

  const BackendErrorBanner({
    super.key,
    required this.errorMessage,
    this.onRetry,
  });

  @override
  State<BackendErrorBanner> createState() => _BackendErrorBannerState();
}

class _BackendErrorBannerState extends State<BackendErrorBanner> {
  bool _isChecking = false;
  String? _checkResult;
  bool _checkSuccess = false;

  bool get _isConnectionError {
    final lower = widget.errorMessage.toLowerCase();
    return lower.contains('conexión') ||
        lower.contains('servidor') ||
        lower.contains('server') ||
        lower.contains('connection') ||
        lower.contains('socket') ||
        lower.contains('host lookup') ||
        lower.contains('api_base_url');
  }

  Future<void> _checkHealth() async {
    setState(() {
      _isChecking = true;
      _checkResult = null;
    });

    final targetUrl = '${ApiConfig.safeBaseUrl}/health';
    try {
      final res = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200 || res.statusCode == 503) {
        setState(() {
          _isChecking = false;
          _checkSuccess = true;
          _checkResult = '¡Servidor backend detectado y respondiendo en $targetUrl!';
        });
      } else {
        setState(() {
          _isChecking = false;
          _checkSuccess = false;
          _checkResult = 'El servidor respondió con código ${res.statusCode}. Verifica los logs de Docker.';
        });
      }
    } catch (e) {
      setState(() {
        _isChecking = false;
        _checkSuccess = false;
        _checkResult = 'Sigue sin responder en $targetUrl. Verifica que "docker compose up" esté corriendo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnectionError) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.errorColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.errorMessage,
                style: const TextStyle(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final targetUrl = ApiConfig.safeBaseUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: AppTheme.errorColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No se pudo conectar con el servidor backend',
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'La aplicación no recibió respuesta desde: $targetUrl',
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pasos para resolver este problema:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                _buildStep(
                  step: '1',
                  text: 'Inicia el backend en tu terminal:',
                  code: 'docker compose up',
                ),
                const SizedBox(height: 6),
                _buildStep(
                  step: '2',
                  text: 'Si usas Flutter Web (Chrome), ejecútalo con el puerto CORS habilitado:',
                  code: 'flutter run -d chrome --dart-define-from-file=.env.client --web-port=8085',
                ),
                const SizedBox(height: 6),
                _buildStep(
                  step: '3',
                  text: 'Verifica que .env.client contenga:',
                  code: 'API_BASE_URL=http://localhost:8000',
                ),
              ],
            ),
          ),
          if (_checkResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _checkSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _checkSuccess ? Colors.green.shade400 : Colors.red.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _checkSuccess ? Icons.check_circle : Icons.cancel,
                    color: _checkSuccess ? Colors.green.shade700 : Colors.red.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _checkResult!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _checkSuccess ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _isChecking ? null : _checkHealth,
                icon: _isChecking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(
                  _isChecking ? 'Verificando...' : 'Comprobar backend',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Reintentar', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep({required String step, required String text, required String code}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                step,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(left: 24),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
