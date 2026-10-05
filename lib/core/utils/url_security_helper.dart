import 'package:url_launcher/url_launcher.dart';

/// Excepción de seguridad ante esquemas de URL prohibidos.
class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);

  @override
  String toString() => message;
}

/// Helper para invocación segura de URLs en SIGAD.
///
/// Mitiga vulnerabilidades de inyección de esquemas peligrosos como `javascript:` o `file:`
/// en Flutter Web y Móvil restringiendo a una lista blanca canónica (`https`, `http`, `tel`, `mailto`).
class UrlSecurityHelper {
  static const Set<String> allowedSchemes = {'https', 'http', 'tel', 'mailto'};

  static Future<bool> launchSafeUrl(Uri uri) async {
    final scheme = uri.scheme.toLowerCase();
    if (!allowedSchemes.contains(scheme)) {
      throw SecurityException('Esquema de URL no permitido por política de seguridad: $scheme');
    }
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }
}
