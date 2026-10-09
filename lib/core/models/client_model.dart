class ClientModel {
  final String id;
  final String identificacion;
  final String nombres;
  final String? email;
  final String? telefono;
  final String? usuarioId;
  final String? codigoVinculacion;
  final DateTime? createdAt;

  const ClientModel({
    required this.id,
    required this.identificacion,
    required this.nombres,
    this.email,
    this.telefono,
    this.usuarioId,
    this.codigoVinculacion,
    this.createdAt,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] as String,
      identificacion: json['identificacion'] as String,
      nombres: json['nombres'] as String,
      email: json['email'] as String?,
      telefono: json['telefono'] as String?,
      usuarioId: json['usuario_id'] as String?,
      codigoVinculacion: json['codigo_vinculacion'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'identificacion': identificacion,
        'nombres': nombres,
        if (email != null) 'email': email,
        if (telefono != null) 'telefono': telefono,
        if (usuarioId != null) 'usuario_id': usuarioId,
        if (codigoVinculacion != null) 'codigo_vinculacion': codigoVinculacion,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}

class CreateClientRequest {
  final String identificacion;
  final String nombres;
  final String? email;
  final String? telefono;

  const CreateClientRequest({
    required this.identificacion,
    required this.nombres,
    this.email,
    this.telefono,
  });

  Map<String, dynamic> toJson() => {
        'identificacion': identificacion,
        'nombres': nombres,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (telefono != null && telefono!.isNotEmpty) 'telefono': telefono,
      };
}
