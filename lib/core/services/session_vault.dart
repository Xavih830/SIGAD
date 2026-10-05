import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sigad/core/constants/storage_keys.dart';

/// Almacén canónico de credenciales y sesión de usuario en SIGAD (CWE-312).
///
/// Multiplataforma nativa:
/// - Android: Android Keystore con EncryptedSharedPreferences (AES-256 GCM).
/// - iOS / macOS: Keychain Services (kSecAttrAccessibleAfterFirstUnlock).
/// - Web: Web Cryptography API (SubtleCrypto con AES-GCM).
/// - Tests Unitarios / CI: In-Memory volátil aislado sin dependencias de plugins nativos.
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

  /// Memoria volátil para pruebas unitarias sin plugins de plataforma.
  static Map<String, dynamic>? _inMemorySession;
  static final Map<String, bool> _inMemoryFlags = {};
  static bool _useInMemory = false;
  static String? _cachedAccessToken;

  /// Token de acceso en memoria para resolución sincrónica ultrarrápida.
  static String? get currentAccessToken => _cachedAccessToken;

  /// Habilita modo en memoria para entornos de testing aislados (Zero Flaky Tests).
  @visibleForTesting
  static void enableTestMode({Map<String, dynamic>? initialSession}) {
    _useInMemory = true;
    _inMemorySession = initialSession;
    _cachedAccessToken = initialSession?['access_token'] as String?;
    _inMemoryFlags.clear();
  }

  /// Restablece el modo de almacenamiento a producción.
  @visibleForTesting
  static void resetTestMode() {
    _useInMemory = false;
    _inMemorySession = null;
    _cachedAccessToken = null;
    _inMemoryFlags.clear();
  }

  /// Inicializa el servicio de sesión en el arranque de la aplicación y precarga el token.
  static Future<void> init() async {
    try {
      await getSession();
    } catch (_) {}
  }

  /// Guarda la sesión activa cifrada en el almacén de seguridad.
  static Future<void> saveSession(Map<String, dynamic> sessionData) async {
    _cachedAccessToken = sessionData['access_token'] as String?;
    if (_useInMemory) {
      _inMemorySession = Map<String, dynamic>.from(sessionData);
      return;
    }
    try {
      final jsonStr = jsonEncode(sessionData);
      await _storage.write(key: _sessionKey, value: jsonStr);
    } catch (_) {
      // Fallback seguro en memoria si falla el canal de plataforma (ej. entornos de test)
      _inMemorySession = Map<String, dynamic>.from(sessionData);
    }
  }

  /// Recupera los datos de la sesión activa descifrados.
  static Future<Map<String, dynamic>?> getSession() async {
    if (_useInMemory) {
      _cachedAccessToken = _inMemorySession?['access_token'] as String?;
      return _inMemorySession;
    }
    try {
      final jsonStr = await _storage.read(key: _sessionKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        _cachedAccessToken = _inMemorySession?['access_token'] as String?;
        return _inMemorySession;
      }
      final decoded = jsonDecode(jsonStr);
      final map = Map<String, dynamic>.from(decoded as Map);
      _cachedAccessToken = map['access_token'] as String?;
      return map;
    } catch (_) {
      _cachedAccessToken = _inMemorySession?['access_token'] as String?;
      return _inMemorySession;
    }
  }

  /// Obtiene de forma directa el token JWT de acceso si existe una sesión válida.
  static Future<String?> getAccessToken() async {
    final session = await getSession();
    if (session == null) return null;
    final token = session['access_token'] as String?;
    return (token != null && token.isNotEmpty) ? token : null;
  }

  /// Pone a cero y purga de forma segura la sesión y sus secretos de memoria y disco.
  static Future<void> clearSession() async {
    _inMemorySession = null;
    _cachedAccessToken = null;
    if (_useInMemory) return;
    try {
      await _storage.delete(key: _sessionKey);
    } catch (_) {
      // Ignorar si el almacenamiento ya estaba limpio
    }
  }

  /// Recupera una bandera booleana no sensible (ej. notificación de bienvenida enviada).
  static Future<bool> getFlag(String key, {bool defaultValue = false}) async {
    if (_useInMemory) {
      return _inMemoryFlags[key] ?? defaultValue;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? defaultValue;
    } catch (_) {
      return _inMemoryFlags[key] ?? defaultValue;
    }
  }

  /// Establece una bandera booleana no sensible en SharedPreferences.
  static Future<void> setFlag(String key, bool value) async {
    _inMemoryFlags[key] = value;
    if (_useInMemory) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // Preservado en memoria fallback
    }
  }
}
