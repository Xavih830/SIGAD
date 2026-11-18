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

  static Map<String, dynamic>? _inMemorySession;
  static final Map<String, bool> _inMemoryFlags = {};
  static bool _useInMemory = false;
  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;

  static String? get currentAccessToken => _cachedAccessToken;
  static String? get currentRefreshToken => _cachedRefreshToken;

  @visibleForTesting
  static void enableTestMode({Map<String, dynamic>? initialSession}) {
    _useInMemory = true;
    _inMemorySession = initialSession != null ? Map<String, dynamic>.from(initialSession) : null;
    _cachedAccessToken = initialSession?['access_token'] as String?;
    _cachedRefreshToken = initialSession?['refresh_token'] as String?;
    _inMemoryFlags.clear();
  }

  @visibleForTesting
  static void resetTestMode() {
    _useInMemory = false;
    _inMemorySession = null;
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
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
    _cachedRefreshToken = sessionData['refresh_token'] as String?;
    final copy = Map<String, dynamic>.from(sessionData);

    if (_useInMemory) {
      _inMemorySession = copy;
      return;
    }
    try {
      final jsonStr = jsonEncode(copy);
      await _storage.write(key: _sessionKey, value: jsonStr);
    } catch (e) {
      debugPrint('[SessionVault] Error al persistir en almacenamiento seguro: $e');
      _inMemorySession = copy;
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
      _cachedRefreshToken = null;
      return null;
    }

    _cachedAccessToken = session['access_token'] as String?;
    _cachedRefreshToken = session['refresh_token'] as String?;
    return session;
  }

  static Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }
    final session = await getSession();
    return session?['access_token'] as String?;
  }

  static Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null && _cachedRefreshToken!.isNotEmpty) {
      return _cachedRefreshToken;
    }
    final session = await getSession();
    return session?['refresh_token'] as String?;
  }

  static Future<void> updateTokens({
    required String access,
    required String refresh,
  }) async {
    _cachedAccessToken = access;
    _cachedRefreshToken = refresh;
    final session = await getSession();
    if (session != null) {
      session['access_token'] = access;
      session['refresh_token'] = refresh;
      await saveSession(session);
    }
  }

  static Future<void> clearSession() async {
    _inMemorySession = null;
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
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
