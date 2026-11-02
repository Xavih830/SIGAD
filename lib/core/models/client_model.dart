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

class UpdateClientRequest {
  final String? nombres;
  final String? email;
  final String? telefono;

  const UpdateClientRequest({
    this.nombres,
    this.email,
    this.telefono,
  });

  Map<String, dynamic> toJson() => {
        if (nombres != null) 'nombres': nombres,
        if (email != null) 'email': email,
        if (telefono != null) 'telefono': telefono,
      };
}

class PaginatedClients {
  final List<ClientModel> items;
  final int total;
  final int skip;
  final int limit;

  const PaginatedClients({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory PaginatedClients.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>;
    return PaginatedClients(
      items: rawItems
          .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      skip: (json['skip'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
    );
  }
}

