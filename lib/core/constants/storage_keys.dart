/// Claves canónicas para persistencia segura en SessionVault y almacenamiento local.
abstract class StorageKeys {
  static const String sessionActiveVault = 'sigad_active_session_v1';
  static const String sessionAccessToken = 'access_token';
  static const String sessionRefreshToken = 'refresh_token';
  static const String sessionUser = 'user';
  static const String biometricEnabled = 'sigad_biometric_enabled';
}
