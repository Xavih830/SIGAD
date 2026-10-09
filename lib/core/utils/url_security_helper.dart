import 'package:url_launcher/url_launcher.dart';

class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);

  @override
  String toString() => message;
}

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
