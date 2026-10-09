import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/models/catalog_model.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/models/deductible_model.dart';
import 'package:sigad/core/models/payment_model.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'helpers/test_factories.dart';
import 'helpers/test_fixtures.dart';

void main() {
  group('Catalog Models Tests (Talleres y Asistencias)', () {
    test('WorkshopModel fromJson and toJson serialization via TestFixtures', () {
      final workshop = WorkshopModel.fromJson(TestFixtures.standardWorkshopJson);
      expect(workshop.id, equals(TestFixtures.standardWorkshop.id));
      expect(workshop.name, equals(TestFixtures.standardWorkshop.name));
      expect(workshop.address, equals(TestFixtures.standardWorkshop.address));
      expect(workshop.phone, equals(TestFixtures.standardWorkshop.phone));
      expect(workshop.city, equals(TestFixtures.standardWorkshop.city));
      expect(workshop.active, equals(TestFixtures.standardWorkshop.active));

      final out = workshop.toJson();
      expect(out['nombre'], equals(TestFixtures.standardWorkshop.name));
      expect(out['ciudad'], equals(TestFixtures.standardWorkshop.city));
    });

    test('AssistanceModel fromJson and toJson serialization via TestFixtures', () {
      final assistance = AssistanceModel.fromJson(TestFixtures.standardAssistanceJson);
      expect(assistance.id, equals(TestFixtures.standardAssistance.id));
      expect(assistance.title, equals(TestFixtures.standardAssistance.title));
      expect(assistance.description, equals(TestFixtures.standardAssistance.description));
      expect(assistance.emergencyPhone, equals(TestFixtures.standardAssistance.emergencyPhone));
      expect(assistance.icon, equals(TestFixtures.standardAssistance.icon));
      expect(assistance.active, equals(TestFixtures.standardAssistance.active));

      final out = assistance.toJson();
      expect(out['titulo'], equals(TestFixtures.standardAssistance.title));
      expect(out['telefono_emergencia'], equals(TestFixtures.standardAssistance.emergencyPhone));
    });
  });

  group('VehicleModel Contract & Invariant Tests', () {
    test('fromJson and toJson round-trip preserves canonical fields', () {
      final model = VehicleModel.fromJson(TestFixtures.standardVehicleJson);
      expect(model.id, equals(TestFixtures.standardVehicle.id));
      expect(model.plate, equals(TestFixtures.standardVehicle.plate));
      expect(model.brand, equals(TestFixtures.standardVehicle.brand));
      expect(model.model, equals(TestFixtures.standardVehicle.model));
      expect(model.year, equals(TestFixtures.standardVehicle.year));

      final outJson = model.toJson();
      expect(outJson['placa'], equals(TestFixtures.standardVehicle.plate));
      expect(outJson['marca'], equals(TestFixtures.standardVehicle.brand));
      expect(outJson['modelo'], equals(TestFixtures.standardVehicle.model));
      expect(outJson['anio'], equals(TestFixtures.standardVehicle.year));
    });

    test('VehicleModel arroja TypeError si faltan campos canonicos (placa)', () {
      final jsonInvalido = TestFactories.createVehicleJson();
      jsonInvalido.remove('placa');
      expect(() => VehicleModel.fromJson(jsonInvalido), throwsA(isA<TypeError>()));
    });

    test('VehicleModel arroja TypeError si anio no es int', () {
      final jsonMalTipado = TestFactories.createVehicleJson();
      jsonMalTipado['anio'] = '2023';
      expect(() => VehicleModel.fromJson(jsonMalTipado), throwsA(isA<TypeError>()));
    });
  });

  group('UserModel Contract & Invariant Tests', () {
    test('fromJson and toJson handle tokens and role mapping correctly', () {
      final user = UserModel.fromJson(TestFixtures.adminUserJson);
      expect(user.id, equals(TestFixtures.adminUser.id));
      expect(user.email, equals(TestFixtures.adminUser.email));
      expect(user.name, equals(TestFixtures.adminUser.name));
      expect(user.role, equals(TestFixtures.adminUser.role));
      expect(user.accessToken, equals(TestFixtures.validToken));
      expect(user.isActive, isTrue);

      final outJson = user.toJson();
      expect(outJson['email'], equals(TestFixtures.adminUser.email));
      expect(outJson['access_token'], equals(TestFixtures.validToken));
    });

    test('UserModel arroja TypeError si falta campo canonico nombre', () {
      final jsonObsoleto = TestFactories.createUserJson();
      jsonObsoleto.remove('nombre');
      expect(() => UserModel.fromJson(jsonObsoleto), throwsA(isA<TypeError>()));
    });

    test('UserModel acepta activo como null y aplica default true', () {
      final jsonSinActivo = TestFactories.createUserJson();
      jsonSinActivo.remove('activo');
      final user = UserModel.fromJson(jsonSinActivo);
      expect(user.isActive, isTrue);
    });
  });

  group('ClientModel Contract & Invariant Tests', () {
    test('fromJson and toJson round-trip preserves canonical fields', () {
      final client = ClientModel.fromJson(TestFixtures.standardClientJson);
      expect(client.id, equals(TestFixtures.standardClient.id));
      expect(client.identificacion, equals(TestFixtures.standardClient.identificacion));
      expect(client.nombres, equals(TestFixtures.standardClient.nombres));
      expect(client.email, equals(TestFixtures.standardClient.email));
      expect(client.telefono, equals(TestFixtures.standardClient.telefono));

      final outJson = client.toJson();
      expect(outJson['identificacion'], equals(TestFixtures.standardClient.identificacion));
      expect(outJson['nombres'], equals(TestFixtures.standardClient.nombres));
      expect(outJson['email'], equals(TestFixtures.standardClient.email));
    });
  });

  group('DeductibleModel Contract & Invariant Tests', () {
    test('fromJson deserializa y serializa con claves canonicas del backend', () {
      final model = DeductibleModel.fromJson(TestFixtures.standardDeductibleJson);
      expect(model.id, equals(TestFixtures.standardDeductible.id));
      expect(model.tipoSiniestro, equals(TestFixtures.standardDeductible.tipoSiniestro));
      expect(model.porcentajeValor, equals(TestFixtures.standardDeductible.porcentajeValor));
      expect(model.montoMinimoUsd, equals(TestFixtures.standardDeductible.montoMinimoUsd));

      final outJson = model.toJson();
      expect(outJson['tipo_siniestro'], equals(TestFixtures.standardDeductible.tipoSiniestro));
      expect(outJson['porcentaje_valor'], equals(TestFixtures.standardDeductible.porcentajeValor));
      expect(outJson['monto_minimo_usd'], equals(TestFixtures.standardDeductible.montoMinimoUsd));
    });

    test('DeductibleModel arroja TypeError si faltan claves canonicas', () {
      final jsonObsoleto = TestFactories.createDeductibleJson();
      jsonObsoleto.remove('tipo_siniestro');
      expect(() => DeductibleModel.fromJson(jsonObsoleto), throwsA(isA<TypeError>()));
    });
  });

  group('PolicyModel & CoverageModel Contract Tests', () {
    test('fromJson and getters calculate daysUntilExpiration and isExpired correctly', () {
      final futureDate = DateTime.now().add(const Duration(days: 15));
      final pastDate = DateTime.now().subtract(const Duration(days: 5));

      final activePolicyJson = TestFactories.createPolicyJson(
        id: TestFixtures.activePolicy.id,
        number: TestFixtures.activePolicy.number,
        clientId: TestFixtures.activePolicy.clientId,
        vehicleId: TestFixtures.activePolicy.vehicleId,
        startDate: DateTime(2026, 1, 1),
        endDate: futureDate,
        status: 'activa',
        vehicle: TestFixtures.standardVehicle,
        coverages: TestFixtures.standardCoverages,
      );

      final policy = PolicyModel.fromJson(activePolicyJson);
      expect(policy.number, equals(TestFixtures.activePolicy.number));
      expect(policy.vehicle?.plate, equals(TestFixtures.standardVehicle.plate));
      expect(policy.coverages.map((c) => c.nombre), contains('Todo Riesgo'));
      expect(policy.isExpired, isFalse);
      expect(policy.isExpiringSoon, isTrue);
      expect(policy.daysUntilExpiration, inInclusiveRange(14, 16));

      final expiredPolicyJson = TestFactories.createPolicyJson(
        id: 'pol-exp-002',
        startDate: DateTime(2026, 1, 1),
        endDate: pastDate,
        status: 'vencida',
      );
      final expiredPolicy = PolicyModel.fromJson(expiredPolicyJson);
      expect(expiredPolicy.isExpired, isTrue);
      expect(expiredPolicy.isExpiringSoon, isFalse);
    });

    test('PolicyModel arroja TypeError si falta numero_poliza', () {
      final jsonIncompleto = TestFactories.createPolicyJson();
      jsonIncompleto.remove('numero_poliza');
      expect(() => PolicyModel.fromJson(jsonIncompleto), throwsA(isA<TypeError>()));
    });

    test('CoverageModel deserializa con claves canonicas del backend', () {
      final cov = CoverageModel.fromJson(TestFixtures.standardCoverageJson);
      expect(cov.id, equals(TestFixtures.standardCoverage.id));
      expect(cov.nombre, equals(TestFixtures.standardCoverage.nombre));
      expect(cov.monto, equals(TestFixtures.standardCoverage.monto));
    });

    test('toCreatePayloadJson serializa estrictamente el esquema PolizaCreate sin campos extra', () {
      final policy = TestFixtures.activePolicy;
      final payload = policy.toCreatePayloadJson();

      expect(payload['numero_poliza'], equals(policy.number));
      expect(payload['cliente_id'], equals(policy.clientId));
      expect(payload['vehiculo_id'], equals(policy.vehicleId));
      expect(payload['valor_asegurado'], equals(policy.insuredValue));
      expect(payload['prima_mensual'], equals(policy.monthlyPremium));
      expect(payload['kilometraje_emision'], equals(policy.emissionMileage));

      expect(payload.containsKey('id'), isFalse);
      expect(payload.containsKey('estado'), isFalse);
      expect(payload.containsKey('vehiculo'), isFalse);
      expect(payload.containsKey('cliente_nombre'), isFalse);

      final deds = payload['deducibles'] as List<dynamic>?;
      if (deds != null && deds.isNotEmpty) {
        for (final d in deds) {
          expect((d as Map).containsKey('id'), isFalse);
        }
      }
      final covs = payload['coberturas'] as List<dynamic>?;
      if (covs != null && covs.isNotEmpty) {
        for (final c in covs) {
          expect((c as Map).containsKey('id'), isFalse);
        }
      }
    });
  });

  group('PaymentModel Contract & Invariant Tests', () {
    test('fromJson y toJson deserializan y exportan cuota pagada via TestFixtures', () {
      final payment = PaymentModel.fromJson(TestFixtures.paidPaymentJson);

      expect(payment.id, equals(TestFixtures.paidPayment.id));
      expect(payment.policyId, equals(TestFixtures.paidPayment.policyId));
      expect(payment.installmentNumber, equals(TestFixtures.paidPayment.installmentNumber));
      expect(payment.amountUsd, equals(TestFixtures.paidPayment.amountUsd));
      expect(payment.dueDate, equals(TestFixtures.paidPayment.dueDate));
      expect(payment.paymentDate, equals(TestFixtures.paidPayment.paymentDate));
      expect(payment.status, equals('pagado'));
      expect(payment.paymentMethod, equals(TestFixtures.paidPayment.paymentMethod));
      expect(payment.receiptRef, equals(TestFixtures.paidPayment.receiptRef));
      expect(payment.isPaid, isTrue);
      expect(payment.isPending, isFalse);
      expect(payment.isOverdue, isFalse);

      final exported = payment.toJson();
      expect(exported['id'], equals(TestFixtures.paidPayment.id));
      expect(exported['numero_cuota'], equals(TestFixtures.paidPayment.installmentNumber));
      expect(exported['estado'], equals('pagado'));
      expect(exported['comprobante_ref'], equals(TestFixtures.paidPayment.receiptRef));
    });

    test('PaymentModel maneja campos nulos y calcula getters de atraso via TestFixtures', () {
      final payment = PaymentModel.fromJson(TestFixtures.overduePaymentJson);

      expect(payment.paymentDate, isNull);
      expect(payment.paymentMethod, isNull);
      expect(payment.receiptRef, isNull);
      expect(payment.isPaid, isFalse);
      expect(payment.isPending, isFalse);
      expect(payment.isOverdue, isTrue);

      final exported = payment.toJson();
      expect(exported['numero_cuota'], equals(TestFixtures.overduePayment.installmentNumber));
      expect(exported['estado'], equals('atrasado'));
      expect(exported.containsKey('fecha_pago'), isFalse);
    });

    test('PaymentModel arroja TypeError si faltan campos obligatorios', () {
      final jsonInvalido = TestFactories.createPaymentJson();
      jsonInvalido.remove('monto_usd');
      expect(() => PaymentModel.fromJson(jsonInvalido), throwsA(isA<TypeError>()));
    });

    test('Modelos soportan cadenas Decimal de FastAPI/OpenAPI sin fallar', () {
      final policyJson = TestFactories.createPolicyJson(asDecimalStrings: true);
      final policy = PolicyModel.fromJson(policyJson);
      expect(policy.insuredValue, isA<double>());
      expect(policy.monthlyPremium, isA<double>());
      expect(policy.deductibles.first.porcentajeValor, isA<double>());
      expect(policy.deductibles.first.montoMinimoUsd, isA<double>());
      expect(policy.coverages.first.monto, isA<double>());

      final paymentJson = TestFactories.createPaymentJson(asDecimalStrings: true);
      final payment = PaymentModel.fromJson(paymentJson);
      expect(payment.amountUsd, isA<double>());
    });
  });
}

