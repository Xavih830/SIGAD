import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/utils/ecuadorian_id_validator.dart';
import 'package:sigad/core/utils/plate_validator.dart';
import 'package:sigad/core/utils/sha256_helper.dart';

void main() {
  group('Ecuadorian ID Validator Tests (Módulo 10)', () {
    test('Valid Ecuadorian IDs should return true', () {
      expect(EcuadorianIdValidator.isValid('0926687856'), isTrue); // Guayas
      expect(EcuadorianIdValidator.isValid('1710034065'), isTrue); // Pichincha
    });

    test('Invalid length IDs should return false', () {
      expect(EcuadorianIdValidator.isValid('092668785'), isFalse); // 9 digits
      expect(EcuadorianIdValidator.isValid('09266878561'), isFalse); // 11 digits
      expect(EcuadorianIdValidator.isValid(''), isFalse); // Empty
    });

    test('Non-numeric IDs should return false', () {
      expect(EcuadorianIdValidator.isValid('092668785a'), isFalse);
      expect(EcuadorianIdValidator.isValid('abcdefghij'), isFalse);
    });

    test('IDs with invalid province digits should return false', () {
      expect(EcuadorianIdValidator.isValid('9926687856'), isFalse); // Province 99 doesn't exist
      expect(EcuadorianIdValidator.isValid('0026687856'), isFalse); // Province 00 doesn't exist
      expect(EcuadorianIdValidator.isValid('2526687856'), isFalse); // Province 25 doesn't exist
    });

    test('IDs with invalid third digit (> 5) should return false', () {
      expect(EcuadorianIdValidator.isValid('0966687856'), isFalse); // Third digit 6
      expect(EcuadorianIdValidator.isValid('1790034065'), isFalse); // Third digit 9
    });

    test('IDs with invalid verifier check digit should return false', () {
      expect(EcuadorianIdValidator.isValid('0926687857'), isFalse); // Expected 6, got 7
      expect(EcuadorianIdValidator.isValid('1710034064'), isFalse); // Expected 5, got 4
    });
  });

  group('SHA-256 Hasher Tests', () {
    test('Hashing same input should yield identical output', () {
      final input = 'Admin#SIGAD24';
      final hash1 = Sha256Helper.hash(input);
      final hash2 = Sha256Helper.hash(input);
      expect(hash1, equals(hash2));
    });

    test('Hashing different inputs should yield different outputs', () {
      final hash1 = Sha256Helper.hash('Admin#SIGAD24');
      final hash2 = Sha256Helper.hash('Carlos#2024');
      expect(hash1, isNot(equals(hash2)));
    });

    test('Hash of empty string should be valid SHA-256 format', () {
      final hash = Sha256Helper.hash('');
      expect(hash.length, equals(64)); // SHA-256 hex digests are exactly 64 characters
    });
  });

  group('PlateValidator Tests (Section 11.2)', () {
    test('Valid plates according to ANT formats', () {
      expect(PlateValidator.isValid('PBA-1234'), isTrue); // Particular
      expect(PlateValidator.isValid('PTA-1234'), isTrue); // Servicio publico
      expect(PlateValidator.isValid('AB-1234'), isTrue); // Moto tradicional
      expect(PlateValidator.isValid('AB-123C'), isTrue); // Moto ANT actual
    });

    test('Invalid plates rejected', () {
      expect(PlateValidator.isValid('XYZ-123'), isFalse); // Antiguo 3D
      expect(PlateValidator.isValid('1234-ABC'), isFalse); // Invertido
      expect(PlateValidator.isValid('AB C-123'), isFalse); // Espacio y 3D
      expect(PlateValidator.isValid('PBA1234'), isFalse); // Sin guion
      expect(PlateValidator.isValid('pba-1234'), isFalse); // Minusculas
      expect(PlateValidator.isValid(''), isFalse); // Vacio
    });
  });
}
