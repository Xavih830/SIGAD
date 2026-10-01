import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/models/catalog_model.dart';
import 'package:sigad/core/models/deductible_model.dart';

import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';

void main() {
  group('Catalog Models Tests (Talleres y Asistencias)', () {
    test('WorkshopModel fromJson and toJson serialization', () {
      final json = {
        'id': 'tal-001',
        'nombre': 'Taller Central Guayaquil',
        'direccion': 'Av. Juan Tanca Marengo Km 4.5',
        'telefono': '04-2598700',
        'ciudad': 'Guayaquil',
        'activo': true,
      };

      final workshop = WorkshopModel.fromJson(json);
      expect(workshop.id, equals('tal-001'));
      expect(workshop.name, equals('Taller Central Guayaquil'));
      expect(workshop.address, equals('Av. Juan Tanca Marengo Km 4.5'));
      expect(workshop.phone, equals('04-2598700'));
      expect(workshop.city, equals('Guayaquil'));
      expect(workshop.active, isTrue);

      final out = workshop.toJson();
      expect(out['nombre'], equals('Taller Central Guayaquil'));
      expect(out['ciudad'], equals('Guayaquil'));
    });

    test('AssistanceModel fromJson and toJson serialization', () {
      final json = {
        'id': 'ast-001',
        'titulo': 'Grúa y Remolque',
        'descripcion': 'Traslado de vehículo averiado.',
        'telefono_emergencia': '1800-757-348',
        'icono': 'local_shipping',
        'activo': true,
      };

      final assistance = AssistanceModel.fromJson(json);
      expect(assistance.id, equals('ast-001'));
      expect(assistance.title, equals('Grúa y Remolque'));
      expect(assistance.description, equals('Traslado de vehículo averiado.'));
      expect(assistance.emergencyPhone, equals('1800-757-348'));
      expect(assistance.icon, equals('local_shipping'));
      expect(assistance.active, isTrue);

      final out = assistance.toJson();
      expect(out['titulo'], equals('Grúa y Remolque'));
      expect(out['telefono_emergencia'], equals('1800-757-348'));
    });
  });

  group('VehicleModel Tests', () {

    test('fromJson and toJson round-trip preserves fields', () {
      final json = {
        'id': 'v-123',
        'placa': 'PBA-1234',
        'marca': 'Chevrolet',
        'modelo': 'Sail',
        'anio': 2021,
        'color': 'Blanco',
        'tipo': 'liviano',
      };

      final model = VehicleModel.fromJson(json);
      expect(model.id, equals('v-123'));
      expect(model.plate, equals('PBA-1234'));
      expect(model.brand, equals('Chevrolet'));
      expect(model.model, equals('Sail'));
      expect(model.year, equals(2021));
      expect(model.color, equals('Blanco'));
      expect(model.type, equals('liviano'));

      final outJson = model.toJson();
      expect(outJson['placa'], equals('PBA-1234'));
      expect(outJson['marca'], equals('Chevrolet'));
      expect(outJson['modelo'], equals('Sail'));
      expect(outJson['anio'], equals(2021));
    });
  });

  group('DeductibleModel Tests', () {
    test('fromJson deserializa con claves canonicas del backend', () {
      final jsonFastApi = {
        'id': 'ded-1',
        'tipo_siniestro': 'robo',
        'porcentaje_valor': 10.5,
        'monto_minimo_usd': 200.0,
      };

      final model = DeductibleModel.fromJson(jsonFastApi);
      expect(model.tipoSiniestro, equals('robo'));
      expect(model.porcentajeValor, equals(10.5));
      expect(model.montoMinimoUsd, equals(200.0));

      final outJson = model.toJson();
      expect(outJson['tipo_siniestro'], equals('robo'));
      expect(outJson['porcentaje_valor'], equals(10.5));
      expect(outJson['monto_minimo_usd'], equals(200.0));
    });
  });

  group('PolicyModel Tests', () {
    test('fromJson and getters calculate daysUntilExpiration and isExpired correctly', () {
      final futureDate = DateTime.now().add(const Duration(days: 15));
      final pastDate = DateTime.now().subtract(const Duration(days: 5));

      final activePolicyJson = {
        'id': 'pol-001',
        'numero_poliza': 'POL-2026-001',
        'cliente_id': 'cli-001',
        'vehiculo_id': 'veh-001',
        'fecha_inicio': '2026-01-01',
        'fecha_fin': futureDate.toIso8601String().substring(0, 10),
        'estado': 'activa',
        'valor_asegurado': 18500.0,
        'prima_mensual': 65.50,
        'kilometraje_emision': 12000,
        'vehiculo': {
          'placa': 'PBA-1234',
          'marca': 'Toyota',
          'modelo': 'Yaris',
          'anio': 2022,
        },
        'deducibles': [
          {
            'id': 'ded-1',
            'tipo_siniestro': 'general',
            'porcentaje_valor': 10.0,
            'monto_minimo_usd': 150.0,
          }
        ],
        'coberturas': [
          {'id': 'cov-1', 'nombre': 'Todo Riesgo', 'monto': 5000},
          {'id': 'cov-2', 'nombre': 'Responsabilidad Civil', 'monto': 3000},
        ],
      };

      final policy = PolicyModel.fromJson(activePolicyJson);
      expect(policy.number, equals('POL-2026-001'));
      expect(policy.vehicle?.plate, equals('PBA-1234'));
      expect(policy.deductibles.length, equals(1));
      expect(policy.deductibles.first.porcentajeValor, equals(10.0));
      expect(policy.coverages.map((c) => c.nombre), contains('Todo Riesgo'));
      expect(policy.isExpired, isFalse);
      expect(policy.isExpiringSoon, isTrue); // 15 days is <= 30
      expect(policy.daysUntilExpiration, inInclusiveRange(14, 16));

      // Expired policy check
      final expiredPolicyJson = {
        ...activePolicyJson,
        'id': 'pol-002',
        'fecha_fin': pastDate.toIso8601String().substring(0, 10),
        'estado': 'vencida',
      };
      final expiredPolicy = PolicyModel.fromJson(expiredPolicyJson);
      expect(expiredPolicy.isExpired, isTrue);
      expect(expiredPolicy.isExpiringSoon, isFalse);
    });
  });

  group('UserModel Tests', () {
    test('fromJson and toJson handle tokens and role mapping correctly', () {
      final userJson = {
        'id': 'usr-001',
        'email': 'admin@sigad.ec',
        'nombre': 'Admin SIGAD',
        'rol': 'admin_system',
        'access_token': 'jwt_mock_token',
        'refresh_token': 'jwt_refresh_mock',
        'activo': true,
      };

      final user = UserModel.fromJson(userJson);
      expect(user.id, equals('usr-001'));
      expect(user.email, equals('admin@sigad.ec'));
      expect(user.name, equals('Admin SIGAD'));
      expect(user.role, equals('admin_system'));
      expect(user.accessToken, equals('jwt_mock_token'));
      expect(user.isActive, isTrue);

      final outJson = user.toJson();
      expect(outJson['email'], equals('admin@sigad.ec'));
      expect(outJson['access_token'], equals('jwt_mock_token'));
    });
  });
}
