import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/core/models/deductible_model.dart';

void main() {
  group('Plan 00-C: Limpieza de Shims y Contrato Canónico OpenAPI', () {
    // ─── VehicleModel ──────────────────────────────────────────────────────────

    test('VehicleModel deserializa estrictamente campos en español', () {
      final jsonOficial = {
        'id': 'veh-123',
        'placa': 'PBA-1234',
        'marca': 'Toyota',
        'modelo': 'Yaris',
        'anio': 2024,
        'cliente_id': 'cli-456',
      };

      final vehicle = VehicleModel.fromJson(jsonOficial);
      expect(vehicle.plate, equals('PBA-1234'));
      expect(vehicle.brand, equals('Toyota'));
      expect(vehicle.model, equals('Yaris'));
      expect(vehicle.year, equals(2024));
      expect(vehicle.clientId, equals('cli-456'));
    });

    test('VehicleModel arroja TypeError si faltan campos canónicos (placa)', () {
      final jsonObsoleto = {
        'id': 'veh-123',
        'plate': 'PBA-1234', // Clave antigua inválida — falta 'placa'
        'brand': 'Toyota',
        'model': 'Yaris',
        'year': 2024,
      };

      // Debe fallar de inmediato (Fail-Fast) sin asumir cadenas vacías
      expect(() => VehicleModel.fromJson(jsonObsoleto), throwsA(isA<TypeError>()));
    });

    test('VehicleModel arroja TypeError si anio no es int', () {
      final jsonMalTipado = {
        'id': 'veh-999',
        'placa': 'ABC-0001',
        'marca': 'Honda',
        'modelo': 'Civic',
        'anio': '2023', // String en vez de int — debe fallar
      };

      expect(() => VehicleModel.fromJson(jsonMalTipado), throwsA(isA<TypeError>()));
    });

    // ─── UserModel ─────────────────────────────────────────────────────────────

    test('UserModel deserializa estrictamente nombre, rol y activo', () {
      final jsonOficial = {
        'id': 'usr-789',
        'email': 'agente@sigad.ec',
        'nombre': 'Carlos Agente',
        'rol': 'agente',
        'activo': true,
      };

      final user = UserModel.fromJson(jsonOficial);
      expect(user.name, equals('Carlos Agente'));
      expect(user.role, equals('agente'));
      expect(user.isActive, isTrue);
    });

    test('UserModel arroja TypeError si falta campo canonico nombre', () {
      final jsonObsoleto = {
        'id': 'usr-789',
        'email': 'agente@sigad.ec',
        'name': 'Carlos Agente', // Clave antigua inválida — falta 'nombre'
        'role': 'agente',        // Clave antigua inválida
        'is_active': true,
      };

      expect(() => UserModel.fromJson(jsonObsoleto), throwsA(isA<TypeError>()));
    });

    test('UserModel acepta activo como null y aplica default true', () {
      final jsonSinActivo = {
        'id': 'usr-100',
        'email': 'admin@sigad.ec',
        'nombre': 'Admin Sistema',
        'rol': 'admin_system',
        // 'activo' ausente → debe asumir true
      };

      final user = UserModel.fromJson(jsonSinActivo);
      expect(user.isActive, isTrue);
    });

    // ─── DeductibleModel ───────────────────────────────────────────────────────

    test('DeductibleModel deserializa con claves canonicas del backend', () {
      final jsonOficial = {
        'id': 'ded-001',
        'tipo_siniestro': 'robo',
        'porcentaje_valor': 10,
        'monto_minimo_usd': 300,
      };

      final ded = DeductibleModel.fromJson(jsonOficial);
      expect(ded.tipoSiniestro, equals('robo'));
      expect(ded.porcentajeValor, equals(10.0));
      expect(ded.montoMinimoUsd, equals(300.0));
    });

    test('DeductibleModel arroja TypeError si faltan claves canonicas', () {
      final jsonObsoleto = {
        'id': 'ded-001',
        'coverageName': 'robo',      // Clave antigua inválida
        'percentage': 10,            // Clave antigua inválida
        'minAmount': 300,            // Clave antigua inválida
      };

      expect(() => DeductibleModel.fromJson(jsonObsoleto), throwsA(isA<TypeError>()));
    });

    // ─── PolicyModel ───────────────────────────────────────────────────────────

    test('PolicyModel deserializa payload canónico completo del backend', () {
      final jsonOficial = {
        'id': 'pol-abc',
        'numero_poliza': 'RJ-2024-001',
        'cliente_id': 'cli-xyz',
        'vehiculo_id': 'veh-xyz',
        'fecha_inicio': '2024-01-15',
        'fecha_fin': '2025-01-15',
        'estado': 'activa',
        'valor_asegurado': 15000,
        'prima_mensual': 120,
        'kilometraje_emision': 45000,
        'deducibles': [],
        'coberturas': [],
      };

      final policy = PolicyModel.fromJson(jsonOficial);
      expect(policy.number, equals('RJ-2024-001'));
      expect(policy.status, equals('activa'));
      expect(policy.insuredValue, equals(15000.0));
      expect(policy.monthlyPremium, equals(120.0));
      expect(policy.emissionMileage, equals(45000));
    });

    test('PolicyModel arroja TypeError si falta numero_poliza', () {
      final jsonIncompleto = {
        'id': 'pol-abc',
        'number': 'RJ-2024-001',  // Clave antigua inválida
        'cliente_id': 'cli-xyz',
        'vehiculo_id': 'veh-xyz',
        'fecha_inicio': '2024-01-15',
        'fecha_fin': '2025-01-15',
        'estado': 'activa',
        'valor_asegurado': 15000,
        'prima_mensual': 120,
        'kilometraje_emision': 45000,
      };

      expect(() => PolicyModel.fromJson(jsonIncompleto), throwsA(isA<TypeError>()));
    });

    // ─── CoverageModel ─────────────────────────────────────────────────────────

    test('CoverageModel deserializa con claves canonicas del backend', () {
      final jsonOficial = {
        'id': 'cov-001',
        'nombre': 'Responsabilidad Civil',
        'monto': 5000,
      };

      final cov = CoverageModel.fromJson(jsonOficial);
      expect(cov.nombre, equals('Responsabilidad Civil'));
      expect(cov.monto, equals(5000.0));
    });
  });
}
