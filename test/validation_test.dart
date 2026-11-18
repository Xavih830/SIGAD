import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/utils/ecuadorian_id_validator.dart';
import 'package:sigad/core/utils/plate_validator.dart';
import 'package:sigad/core/testing/test_fixtures.dart';

void main() {
  group('Ecuadorian ID Validator Tests (Módulo 10)', () {
    test('Valid Ecuadorian IDs should return true', () {
      expect(EcuadorianIdValidator.isValid(TestFixtures.validCedula), isTrue);
      expect(EcuadorianIdValidator.isValid('1710034065'), isTrue);
    });

    test('Invalid length IDs should return false', () {
      expect(EcuadorianIdValidator.isValid('092668785'), isFalse);
      expect(EcuadorianIdValidator.isValid('09266878561'), isFalse);
      expect(EcuadorianIdValidator.isValid(''), isFalse);
    });

    test('Non-numeric IDs should return false', () {
      expect(EcuadorianIdValidator.isValid('092668785a'), isFalse);
      expect(EcuadorianIdValidator.isValid('abcdefghij'), isFalse);
    });

    test('IDs with invalid province digits should return false', () {
      expect(EcuadorianIdValidator.isValid('9926687856'), isFalse);
      expect(EcuadorianIdValidator.isValid('0026687856'), isFalse);
      expect(EcuadorianIdValidator.isValid('2526687856'), isFalse);
    });

    test('IDs with invalid third digit (> 5) should return false', () {
      expect(EcuadorianIdValidator.isValid('0966687856'), isFalse);
      expect(EcuadorianIdValidator.isValid('1790034065'), isFalse);
    });

    test('IDs with invalid verifier check digit should return false', () {
      expect(EcuadorianIdValidator.isValid('0926687857'), isFalse);
      expect(EcuadorianIdValidator.isValid('1710034064'), isFalse);
    });
  });

  group('Ecuadorian RUC Validator Tests (SRI)', () {
    test('Valid RUCs should return true', () {
      // Persona natural
      expect(EcuadorianIdValidator.isValidRuc('0926687856001'), isTrue);
      expect(EcuadorianIdValidator.isValidRuc('1710034065001'), isTrue);
      // Sociedad pública
      expect(EcuadorianIdValidator.isValidRuc('1760000820001'), isTrue);
      // Sociedad privada
      expect(EcuadorianIdValidator.isValidRuc('1790016919001'), isTrue);
    });

    test('Invalid RUCs should return false', () {
      expect(EcuadorianIdValidator.isValidRuc('092668785600'), isFalse); // 12 digits
      expect(EcuadorianIdValidator.isValidRuc('09266878560001'), isFalse); // 14 digits
      expect(EcuadorianIdValidator.isValidRuc('092668785600a'), isFalse); // non-numeric
      expect(EcuadorianIdValidator.isValidRuc('0026687856001'), isFalse); // invalid province
      expect(EcuadorianIdValidator.isValidRuc('0926687856000'), isFalse); // invalid establishment
      expect(EcuadorianIdValidator.isValidRuc('1760000830001'), isFalse); // bad check public
      expect(EcuadorianIdValidator.isValidRuc('1790016918001'), isFalse); // bad check private
      expect(EcuadorianIdValidator.isValidRuc('1770016919001'), isFalse); // bad third digit
    });

    test('isValidIdentificacion accepts both cédula and RUC', () {
      expect(EcuadorianIdValidator.isValidIdentificacion('0926687856'), isTrue);
      expect(EcuadorianIdValidator.isValidIdentificacion('1790016919001'), isTrue);
      expect(EcuadorianIdValidator.isValidIdentificacion('1760000820001'), isTrue);
      expect(EcuadorianIdValidator.isValidIdentificacion('0926687856001'), isTrue);
      expect(EcuadorianIdValidator.isValidIdentificacion('0926687857'), isFalse);
      expect(EcuadorianIdValidator.isValidIdentificacion('1790016918001'), isFalse);
      expect(EcuadorianIdValidator.isValidIdentificacion('12345'), isFalse);
    });
  });

  group('PlateValidator and Classification Tests (D5)', () {
    test('Valid plates according to ANT formats', () {
      expect(PlateValidator.isValid(TestFixtures.standardVehicle.plate), isTrue);
      expect(isValidPlate('PBA-1234'), isTrue);
      expect(isValidPlate('PTA-1234'), isTrue);
      expect(isValidPlate('AB-1234'), isTrue);
      expect(isValidPlate('AB-123C'), isTrue);
      expect(isValidPlate('AB-000A'), isTrue);
      expect(isValidPlate('XXX-0000'), isTrue);
      expect(isValidPlate('XXX-9999'), isTrue);
    });

    test('Invalid plates rejected', () {
      expect(isValidPlate('XYZ-123'), isFalse);
      expect(isValidPlate('1234-ABC'), isFalse);
      expect(isValidPlate('AB C-123'), isFalse);
      expect(isValidPlate('PBA1234'), isFalse);
      expect(isValidPlate('pba-1234'), isFalse);
      expect(isValidPlate(''), isFalse);
      expect(isValidPlate('ab-000a'), isFalse);
      expect(isValidPlate('AB-000a'), isFalse);
      expect(isValidPlate('AB-12345'), isFalse);
    });

    test('Plate classification by equivalence partition according to D5', () {
      // Particular
      expect(classifyPlate('PBA-1234'), PlateType.particular);
      expect(classifyPlate('GYE-0987'), PlateType.particular);
      expect(classifyPlate('ICA-0001'), PlateType.particular);
      expect(classifyPlate('PTA-1234'), PlateType.particular);

      // Moto
      expect(classifyPlate('AB-1234'), PlateType.moto);
      expect(classifyPlate('AB-123C'), PlateType.moto);
      expect(classifyPlate('AB-000A'), PlateType.moto);

      // Servicio público
      expect(classifyPlate('GAA-1234'), PlateType.servicioPublico);
      expect(classifyPlate('PUB-0001'), PlateType.servicioPublico);
      expect(classifyPlate('PZA-9999'), PlateType.servicioPublico);

      // Gubernamental
      expect(classifyPlate('PEA-1234'), PlateType.gubernamental);
      expect(classifyPlate('PXA-1234'), PlateType.gubernamental);
      expect(classifyPlate('PMA-0001'), PlateType.gubernamental);
      expect(classifyPlate('PSA-1234'), PlateType.gubernamental);
      expect(classifyPlate('XXX-0000'), PlateType.gubernamental);
      expect(classifyPlate('XXX-9999'), PlateType.gubernamental);

      // Inválidas devuelven null
      expect(classifyPlate('XYZ-123'), isNull);
      expect(classifyPlate('pba-1234'), isNull);
      expect(classifyPlate(''), isNull);
    });
  });
}

