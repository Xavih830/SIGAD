import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/utils/date_formatter.dart';

void main() {
  group('DateFormatter Tests', () {
    test('toIsoDate genera formato AAAA-MM-DD con padding de ceros', () {
      final dt = DateTime(2026, 5, 4);
      expect(DateFormatter.toIsoDate(dt), '2026-05-04');
    });

    test('toIsoDate maneja fin de año y meses de dos dígitos', () {
      final dt = DateTime(2026, 12, 31);
      expect(DateFormatter.toIsoDate(dt), '2026-12-31');
    });

    test('parseIsoDate deserializa correctamente una cadena ISO', () {
      final dt = DateFormatter.parseIsoDate('2026-10-09');
      expect(dt.year, 2026);
      expect(dt.month, 10);
      expect(dt.day, 9);
    });

    test('formatDisplay genera formato DD/MM/AAAA para presentación', () {
      final dt = DateTime(2026, 7, 3);
      expect(DateFormatter.formatDisplay(dt), '03/07/2026');
    });
  });
}
