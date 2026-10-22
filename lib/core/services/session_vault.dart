import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sigad/core/constants/storage_keys.dart';

class SessionVault {
  static const String _sessionKey = StorageKeys.sessionActiveVault;

  static final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    webOptions: WebOptions(
      dbName: 'sigad_secure_vault',
      publicKey: 'sigad_vault_pk',
    ),
  );

  static const int currentVaultVersion = 2;
  static const Duration maxWebSessionDuration = Duration(minutes: 30);

  static Map<String, dynamic>? _inMemorySession;
  static final Map<String, bool> _inMemoryFlags = {};
  static bool _useInMemory = false;
  static String? _cachedAccessToken;

  static String? get currentAccessToken => _cachedAccessToken;

  @visibleForTesting
  static void enableTestMode({Map<String, dynamic>? initialSession}) {
    _useInMemory = true;
    _inMemorySession = initialSession;
    _cachedAccessToken = initialSession?['access_token'] as String?;
    _inMemoryFlags.clear();
  }

  @visibleForTesting
  static void resetTestMode() {
    _useInMemory = false;
    _inMemorySession = null;
    _cachedAccessToken = null;
    _inMemoryFlags.clear();
  }

  static Future<void> init() async {
    try {
      await getSession();
    } catch (e) {
      debugPrint('[SessionVault] Error al inicializar bóveda: $e');
    }
  }

  static Future<void> saveSession(Map<String, dynamic> sessionData) async {
    _cachedAccessToken = sessionData['access_token'] as String?;
    final enriched = Map<String, dynamic>.from(sessionData);
    enriched['vault_version'] = currentVaultVersion;
    enriched['saved_at'] = DateTime.now().millisecondsSinceEpoch;

    if (_useInMemory) {
      _inMemorySession = enriched;
      return;
    }
    try {
      final jsonStr = jsonEncode(enriched);
      await _storage.write(key: _sessionKey, value: jsonStr);
    } catch (e) {
      debugPrint('[SessionVault] Error al persistir en almacenamiento seguro: $e');
      _inMemorySession = enriched;
    }
  }

  static Future<Map<String, dynamic>?> getSession() async {
    Map<String, dynamic>? session;
    if (_useInMemory) {
      session = _inMemorySession;
    } else {
      try {
        final jsonStr = await _storage.read(key: _sessionKey);
        if (jsonStr == null || jsonStr.isEmpty) {
          session = _inMemorySession;
        } else {
          final decoded = jsonDecode(jsonStr);
          session = Map<String, dynamic>.from(decoded as Map);
        }
      } catch (e) {
        debugPrint('[SessionVault] Error al leer de almacenamiento seguro: $e');
        session = _inMemorySession;
      }
    }

    if (session == null) {
      _cachedAccessToken = null;
      return null;
    }

    // Política de Seguridad y Confort:
    // En Web (kIsWeb): expira estrictamente al alcanzar el límite máximo de minutos (30m) o exp JWT.
    // En Móvil (!kIsWeb): se mantiene persistente en el dispositivo para conveniencia y confort del usuario.
    if (kIsWeb && !_useInMemory) {
      if (_isWebSessionExpired(session)) {
        debugPrint('[SessionVault] Sesión Web expirada por política de seguridad y límite de tiempo.');
        await clearSession();
        return null;
      }
    }

    _cachedAccessToken = session['access_token'] as String?;
    return session;
  }

  static bool _isWebSessionExpired(Map<String, dynamic> session) {
    // 1. Invalida sesiones de esquemas / versiones previas corruptas
    final version = session['vault_version'];
    if (version != null && version != currentVaultVersion) {
      return true;
    }

    // 2. Control estricto de tiempo transcurrido desde el inicio de sesión web
    final savedAtMs = session['saved_at'] as int?;
    if (savedAtMs != null) {
      final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
      if (DateTime.now().difference(savedAt) > maxWebSessionDuration) {
        return true;
      }
    }

    // 3. Verificación de expiración intrínseca de claim 'exp' en el JWT
    final token = session['access_token'] as String?;
    if (token != null && token.isNotEmpty) {
      final expDate = _extractJwtExpiry(token);
      if (expDate != null && DateTime.now().toUtc().isAfter(expDate)) {
        return true;
      }
    }

    return false;
  }

  static DateTime? _extractJwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var normalized = base64Url.normalize(parts[1]);
      final payloadStr = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      if (payload.containsKey('exp') && payload['exp'] is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          (payload['exp'] as int) * 1000,
          isUtc: true,
        );
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> getAccessToken() async {
    final session = await getSession();
    if (session == null) return null;
    final token = session['access_token'] as String?;
    return (token != null && token.isNotEmpty) ? token : null;
  }

  static Future<void> clearSession() async {
    _inMemorySession = null;
    _cachedAccessToken = null;
    if (_useInMemory) return;
    try {
      await _storage.delete(key: _sessionKey);
    } catch (e) {
      debugPrint('[SessionVault] Error al eliminar sesión segura: $e');
    }
  }

  static Future<bool> getFlag(String key, {bool defaultValue = false}) async {
    if (_useInMemory) {
      return _inMemoryFlags[key] ?? defaultValue;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? defaultValue;
    } catch (e) {
      debugPrint('[SessionVault] Error al leer preferencia $key: $e');
      return _inMemoryFlags[key] ?? defaultValue;
    }
  }

  static Future<void> setFlag(String key, bool value) async {
    _inMemoryFlags[key] = value;
    if (_useInMemory) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('[SessionVault] Error al guardar preferencia $key: $e');
    }
  }
}
