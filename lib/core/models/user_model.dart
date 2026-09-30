class UserModel {
  final String id;
  final String email;
  final String name;
  final String role; // 'admin_system', 'admin_rjseguros', 'client'
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
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['nombre'] ?? json['name'] ?? '',
      role: json['rol'] ?? json['role'] ?? 'client',
      accessToken: json['access_token'] ?? json['accessToken'],
      refreshToken: json['refresh_token'] ?? json['refreshToken'],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'role': role,
    if (accessToken != null) 'access_token': accessToken,
    if (refreshToken != null) 'refresh_token': refreshToken,
    'isActive': isActive,
  };
}
