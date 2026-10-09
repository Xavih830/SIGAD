import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/utils/ecuadorian_id_validator.dart';
import 'package:sigad/core/utils/plate_validator.dart';
import 'helpers/test_fixtures.dart';

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

  group('PlateValidator Tests', () {
    test('Valid plates according to ANT formats', () {
      expect(PlateValidator.isValid(TestFixtures.standardVehicle.plate), isTrue);
      expect(PlateValidator.isValid('PBA-1234'), isTrue);
      expect(PlateValidator.isValid('PTA-1234'), isTrue);
      expect(PlateValidator.isValid('AB-1234'), isTrue);
      expect(PlateValidator.isValid('AB-123C'), isTrue);
    });

    test('Invalid plates rejected', () {
      expect(PlateValidator.isValid('XYZ-123'), isFalse);
      expect(PlateValidator.isValid('1234-ABC'), isFalse);
      expect(PlateValidator.isValid('AB C-123'), isFalse);
      expect(PlateValidator.isValid('PBA1234'), isFalse);
      expect(PlateValidator.isValid('pba-1234'), isFalse);
      expect(PlateValidator.isValid(''), isFalse);
    });
  });
}
