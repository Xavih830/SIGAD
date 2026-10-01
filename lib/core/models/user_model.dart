/// Modelo canónico para Usuarios en SIGAD.
///
/// Contrato estricto OpenAPI — sin shims bilingüe ni fallbacks silenciosos.
/// Falla-Rápido: lanza TypeError si el backend omite campos requeridos.
class UserModel {
  final String id;
  final String email;
  final String name;
  final String role; // 'admin_system', 'admin_rjseguros', 'agente', 'cliente'
  final String? accessToken;
  final String? refreshToken;
  final bool isActive;

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
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['nombre'] as String,
      role: json['rol'] as String,
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      isActive: json['activo'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nombre': name,
        'rol': role,
        'activo': isActive,
        if (accessToken != null) 'access_token': accessToken,
        if (refreshToken != null) 'refresh_token': refreshToken,
      };
}
