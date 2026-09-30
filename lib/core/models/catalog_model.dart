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
      id: json['id']?.toString() ?? '',
      code: json['codigo'] ?? json['code'] ?? '',
      name: json['nombre'] ?? json['name'] ?? '',
      description: json['descripcion'] ?? json['description'],
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
      id: json['id']?.toString() ?? '',
      name: json['nombre'] ?? json['name'] ?? '',
      address: json['direccion'] ?? json['address'] ?? '',
      phone: json['telefono'] ?? json['phone'] ?? '',
      city: json['ciudad'] ?? json['city'] ?? '',
      active: json['activo'] ?? json['active'] ?? true,
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
      id: json['id']?.toString() ?? '',
      title: json['titulo'] ?? json['type'] ?? json['title'] ?? 'Asistencia',
      description: json['descripcion'] ?? json['description'] ?? '',
      emergencyPhone: json['telefono_emergencia'] ?? json['phone'] ?? json['emergencyPhone'] ?? '',
      icon: json['icono'] ?? json['icon'] ?? 'phone',
      active: json['activo'] ?? json['active'] ?? true,
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
