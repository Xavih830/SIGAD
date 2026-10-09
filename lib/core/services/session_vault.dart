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
    } catch (_) {}
  }

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
      _inMemorySession = Map<String, dynamic>.from(sessionData);
    }
  }

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
    } catch (_) {}
  }

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

  static Future<void> setFlag(String key, bool value) async {
    _inMemoryFlags[key] = value;
    if (_useInMemory) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }
}
