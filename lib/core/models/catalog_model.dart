class CatalogItemModel {
  final String id;
  final String code;
  final String name;
  final String? description;

  const CatalogItemModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
  });

  factory CatalogItemModel.fromJson(Map<String, dynamic> json) {
    return CatalogItemModel(
      id: json['id'] as String,
      code: json['codigo'] as String,
      name: json['nombre'] as String,
      description: json['descripcion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'codigo': code,
    'nombre': name,
    if (description != null) 'descripcion': description,
  };
}

class WorkshopModel {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String city;
  final bool active;

  const WorkshopModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.city,
    this.active = true,
  });

  factory WorkshopModel.fromJson(Map<String, dynamic> json) {
    return WorkshopModel(
      id: json['id'] as String,
      name: json['nombre'] as String,
      address: json['direccion'] as String,
      phone: json['telefono'] as String,
      city: json['ciudad'] as String,
      active: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': name,
    'direccion': address,
    'telefono': phone,
    'ciudad': city,
    'activo': active,
  };
}

class AssistanceModel {
  final String id;
  final String title;
  final String description;
  final String emergencyPhone;
  final String icon;
  final bool active;

  const AssistanceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.emergencyPhone,
    required this.icon,
    this.active = true,
  });

  factory AssistanceModel.fromJson(Map<String, dynamic> json) {
    return AssistanceModel(
      id: json['id'] as String,
      title: json['titulo'] as String,
      description: json['descripcion'] as String,
      emergencyPhone: json['telefono_emergencia'] as String,
      icon: json['icono'] as String,
      active: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': title,
    'descripcion': description,
    'telefono_emergencia': emergencyPhone,
    'icono': icon,
    'activo': active,
  };
}

/// DTO para la creación administrativa de un nuevo taller mecánico autorizado.
class CreateWorkshopRequest {
  final String nombre;
  final String direccion;
  final String telefono;
  final String ciudad;
  final bool activo;

  const CreateWorkshopRequest({
    required this.nombre,
    required this.direccion,
    required this.telefono,
    required this.ciudad,
    this.activo = true,
  });

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'direccion': direccion,
    'telefono': telefono,
    'ciudad': ciudad,
    'activo': activo,
  };
}

/// DTO para la creación administrativa de un nuevo servicio de asistencia.
class CreateAssistanceRequest {
  final String titulo;
  final String descripcion;
  final String telefonoEmergencia;
  final String icono;
  final bool activo;

  const CreateAssistanceRequest({
    required this.titulo,
    required this.descripcion,
    required this.telefonoEmergencia,
    this.icono = 'phone',
    this.activo = true,
  });

  Map<String, dynamic> toJson() => {
    'titulo': titulo,
    'descripcion': descripcion,
    'telefono_emergencia': telefonoEmergencia,
    'icono': icono,
    'activo': activo,
  };
}
