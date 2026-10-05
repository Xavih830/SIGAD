/// Roles canónicos de usuarios en SIGAD según contrato OpenAPI.
enum UserRole {
  admin('admin', 'Administrador'),
  agente('agente', 'Agente Autorizado'),
  cliente('cliente', 'Cliente Asegurado');

  final String value;
  final String label;
  const UserRole(this.value, this.label);

  static UserRole fromValue(String value) {
    for (final role in UserRole.values) {
      if (role.value == value) return role;
    }
    throw StateError('FAIL-FAST: Rol desconocido del backend: "$value"');
  }
}

/// Modelo canónico para Usuarios en SIGAD.
///
/// Contrato estricto OpenAPI — sin shims bilingüe ni fallbacks silenciosos.
/// Falla-Rápido: lanza TypeError o StateError si el backend omite campos requeridos.
class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? accessToken;
  final String? refreshToken;
  final bool isActive;

  bool get isAdmin => role == UserRole.admin;
  bool get isAgent => role == UserRole.agente;
  bool get isClient => role == UserRole.cliente;
  bool get isStaff => isAdmin || isAgent;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.accessToken,
    this.refreshToken,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawRole = json['rol'] as String;
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['nombre'] as String,
      role: UserRole.fromValue(rawRole),
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      isActive: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nombre': name,
        'rol': role.value,
        'activo': isActive,
        if (accessToken != null) 'access_token': accessToken,
        if (refreshToken != null) 'refresh_token': refreshToken,
      };
}
