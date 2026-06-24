import 'package:hive_flutter/hive_flutter.dart';
import '../utils/sha256_helper.dart';

class HiveHelper {
  static const String usersBoxName = 'users';
  static const String clientsBoxName = 'clients';
  static const String policiesBoxName = 'policies';
  static const String sessionBoxName = 'session';
  static const String workshopsBoxName = 'workshops';
  static const String assistanceBoxName = 'assistance';

  static Box get usersBox => Hive.box(usersBoxName);
  static Box get clientsBox => Hive.box(clientsBoxName);
  static Box get policiesBox => Hive.box(policiesBoxName);
  static Box get sessionBox => Hive.box(sessionBoxName);
  static Box get workshopsBox => Hive.box(workshopsBoxName);
  static Box get assistanceBox => Hive.box(assistanceBoxName);

  static Future<void> init() async {
    await Hive.initFlutter();
    
    await Hive.openBox(usersBoxName);
    await Hive.openBox(clientsBoxName);
    await Hive.openBox(policiesBoxName);
    await Hive.openBox(sessionBoxName);
    await Hive.openBox(workshopsBoxName);
    await Hive.openBox(assistanceBoxName);

    await seedDataIfNeeded();
  }

  static Future<void> seedDataIfNeeded() async {
    // 1. Seed Users
    if (usersBox.isEmpty) {
      final defaultUsers = [
        {
          'email': 'admin@sigad.ec',
          'name': 'Administrador del Sistema',
          'passwordHash': Sha256Helper.hash('Admin#SIGAD24'),
          'role': 'admin_system',
          'isActive': true,
        },
        {
          'email': 'ariana@rjseguros.ec',
          'name': 'Ariana Guerrón',
          'passwordHash': Sha256Helper.hash('RJAdmin#2024'),
          'role': 'admin_rjseguros',
          'isActive': true,
        },
        {
          'email': 'c.perez@gmail.com',
          'name': 'Carlos Eduardo Pérez Morales',
          'passwordHash': Sha256Helper.hash('Carlos#2024'),
          'role': 'client',
          'isActive': true,
        },
        {
          'email': 'm.leon@hotmail.com',
          'name': 'María José León Andrade',
          'passwordHash': Sha256Helper.hash('Maria#2024'),
          'role': 'client',
          'isActive': true,
        },
        {
          'email': 'r.vega@gmail.com',
          'name': 'Roberto Antonio Vega Cruz',
          'passwordHash': Sha256Helper.hash('Roberto#2024'),
          'role': 'client',
          'isActive': true,
        }
      ];

      for (var u in defaultUsers) {
        await usersBox.put(u['email'], u);
      }
    }

    // 2. Seed Clients
    if (clientsBox.isEmpty) {
      final defaultClients = [
        {
          'id': '0912345678',
          'name': 'Carlos Eduardo Pérez Morales',
          'email': 'c.perez@gmail.com',
          'phone': '0987654321',
        },
        {
          'id': '0923456789',
          'name': 'María José León Andrade',
          'email': 'm.leon@hotmail.com',
          'phone': '0976543210',
        },
        {
          'id': '0934567890',
          'name': 'Roberto Antonio Vega Cruz',
          'email': 'r.vega@gmail.com',
          'phone': '0965432109',
        }
      ];

      for (var c in defaultClients) {
        await clientsBox.put(c['id'], c);
      }
    }

    // 3. Seed Policies
    if (policiesBox.isEmpty) {
      final defaultPolicies = [
        {
          'number': 'POL-VL-2024-001',
          'clientEmail': 'c.perez@gmail.com',
          'clientName': 'Carlos Eduardo Pérez Morales',
          'clientDoc': '0912345678',
          'vehicleBrand': 'Toyota',
          'vehicleModel': 'Corolla',
          'vehicleYear': 2020,
          'vehicleColor': 'Blanco',
          'plate': 'GPA-1234',
          'type': 'liviano',
          'coverages': ['Daños propios', 'Responsabilidad civil', 'Accidentes personales', 'Asistencia en carretera'],
          'value': 18500.00,
          'prima': 52.30,
          'startDate': '2024-01-15',
          'endDate': '2025-01-15',
          'status': 'activa',
          'tonnage': 0.0,
          'isDeleted': false,
          'changesHistory': [],
          'attachments': [],
          'paymentStatus': 'Al día',
          'lastPaymentDate': '2024-12-15',
        },
        {
          'number': 'POL-VL-2024-002',
          'clientEmail': 'm.leon@hotmail.com',
          'clientName': 'María José León Andrade',
          'clientDoc': '0923456789',
          'vehicleBrand': 'Chevrolet',
          'vehicleModel': 'Sail',
          'vehicleYear': 2022,
          'vehicleColor': 'Gris',
          'plate': 'GPB-5678',
          'type': 'liviano',
          'coverages': ['Daños propios', 'Responsabilidad civil', 'Robo total'],
          'value': 14200.00,
          'prima': 41.80,
          'startDate': '2024-03-03',
          'endDate': '2025-03-03',
          'status': 'activa',
          'tonnage': 0.0,
          'isDeleted': false,
          'changesHistory': [],
          'attachments': [],
          'paymentStatus': 'Al día',
          'lastPaymentDate': '2025-02-03',
        },
        {
          'number': 'POL-VP-2024-003',
          'clientEmail': 'r.vega@gmail.com',
          'clientName': 'Roberto Antonio Vega Cruz',
          'clientDoc': '0934567890',
          'vehicleBrand': 'Hino',
          'vehicleModel': '300',
          'vehicleYear': 2019,
          'vehicleColor': 'Amarillo',
          'plate': 'GPC-9012',
          'type': 'pesado',
          'coverages': ['Daños propios', 'Responsabilidad civil ampliada', 'Carga transportada'],
          'value': 42000.00,
          'prima': 185.00,
          'startDate': '2024-06-20',
          'endDate': '2025-06-20',
          'status': 'activa',
          'tonnage': 4.5,
          'isDeleted': false,
          'changesHistory': [],
          'attachments': [],
          'paymentStatus': 'Al día',
          'lastPaymentDate': '2025-05-20',
        }
      ];

      for (var p in defaultPolicies) {
        await policiesBox.put(p['number'], p);
      }
    }

    // 4. Seed Workshops
    if (workshopsBox.isEmpty) {
      final defaultWorkshops = [
        {
          'name': 'Taller Automotriz Espinoza',
          'address': 'Av. Carlos Julio Arosemena Km 2.5, Guayaquil',
          'phone': '04-2234567',
          'specialty': 'Carrocería y mecánica general',
        },
        {
          'name': 'Centro Automotriz del Pacífico',
          'address': 'Av. de las Américas 1250, Guayaquil',
          'phone': '04-2345678',
          'specialty': 'Mecánica automotriz y electricidad',
        },
        {
          'name': 'Tecnicar Service Center',
          'address': 'Vía a Samborondón Km 1.2, Samborondón',
          'phone': '04-2456789',
          'specialty': 'Diagnóstico computarizado y mecánica',
        }
      ];

      for (var i = 0; i < defaultWorkshops.length; i++) {
        await workshopsBox.put(i.toString(), defaultWorkshops[i]);
      }
    }

    // 5. Seed Assistance Numbers
    if (assistanceBox.isEmpty) {
      final defaultAssistance = [
        {
          'type': 'Grúa',
          'phone': '1800-742431',
          'icon': 'local_shipping',
        },
        {
          'type': 'Auxilio mecánico',
          'phone': '1800-742432',
          'icon': 'build',
        },
        {
          'type': 'Asistencia en viaje',
          'phone': '1800-742433',
          'icon': 'explore',
        },
        {
          'type': 'Emergencias',
          'phone': '1800-742434',
          'icon': 'emergency',
        }
      ];

      for (var i = 0; i < defaultAssistance.length; i++) {
        await assistanceBox.put(i.toString(), defaultAssistance[i]);
      }
    }
  }
}
