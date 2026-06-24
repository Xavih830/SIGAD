import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/utils/ecuadorian_id_validator.dart';
import 'package:sigad/core/utils/sha256_helper.dart';

void main() {
  group('Ecuadorian ID Validator Tests', () {
    test('Valid Ecuadorian IDs should return true', () {
      // Seed IDs from SRS
      expect(EcuadorianIdValidator.isValid('0912345678'), isTrue);
      expect(EcuadorianIdValidator.isValid('0923456789'), isTrue);
      expect(EcuadorianIdValidator.isValid('0934567890'), isTrue);
    });

    test('Invalid length IDs should return false', () {
      expect(EcuadorianIdValidator.isValid('091234567'), isFalse); // 9 digits
      expect(EcuadorianIdValidator.isValid('09123456789'), isFalse); // 11 digits
      expect(EcuadorianIdValidator.isValid(''), isFalse); // Empty
    });

    test('Non-numeric IDs should return false', () {
      expect(EcuadorianIdValidator.isValid('091234567a'), isFalse);
      expect(EcuadorianIdValidator.isValid('abcdefghij'), isFalse);
    });

    test('IDs with invalid province digits should return false', () {
      expect(EcuadorianIdValidator.isValid('9912345678'), isFalse); // Province 99 doesn't exist
      expect(EcuadorianIdValidator.isValid('0012345678'), isFalse); // Province 00 doesn't exist
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
}
