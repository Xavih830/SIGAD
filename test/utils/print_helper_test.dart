import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/utils/print/print_helper.dart';

void main() {
  group('PrintHelper Unit Tests', () {
    test('triggerPrint invoca implementación de plataforma sin lanzar excepciones', () {
      expect(() => triggerPrint(), returnsNormally);
      expect(() => triggerPrint(htmlContent: '<html><body>Prueba A4</body></html>'), returnsNormally);
    });
  });
}

