import 'dart:typed_data';
import 'package:sigad/core/constants/app_constants.dart';

/// Servicio de dominio para validación de seguridad de archivos pre-vuelo.
/// Erradica el 'Tangling' de validación de bytes dentro de repositorios HTTP.
abstract class FileSecurityValidator {
  /// Valida la integridad, tamaño y firmas binarias (Magic Bytes) de un archivo
  /// antes de iniciar el envío multipart a la red.
  ///
  /// Lanza [ArgumentError] con descripción fail-fast si el archivo es inválido.
  static void validatePreFlight({
    required Uint8List bytes,
    required String filename,
  }) {
    if (bytes.isEmpty) {
      throw ArgumentError('FAIL-FAST: El archivo "$filename" está vacío.');
    }

    if (bytes.length > AppConstants.maxDocumentSizeBytes) {
      throw ArgumentError(
        'FAIL-FAST: El archivo excede el tamaño máximo permitido de 15 MB '
        '(${bytes.length} bytes recibidos).',
      );
    }

    final ext = filename.toLowerCase().split('.').last;
    if (!AppConstants.permittedExtensions.contains(ext)) {
      throw ArgumentError(
        'FAIL-FAST: Extensión ".$ext" no permitida. Formatos válidos: '
        '${AppConstants.permittedExtensions.join(', ')}.',
      );
    }

    // Validación de Magic Bytes (Firmas Binarias Reales - CWE-434)
    if (ext == 'pdf') {
      if (bytes.length < 5 ||
          bytes[0] != 0x25 ||
          bytes[1] != 0x50 ||
          bytes[2] != 0x44 ||
          bytes[3] != 0x46 ||
          bytes[4] != 0x2D) {
        throw ArgumentError('FAIL-FAST: Firma binaria no corresponde a un archivo PDF legítimo (%PDF-).');
      }
    } else if (ext == 'jpg' || ext == 'jpeg') {
      if (bytes.length < 3 ||
          bytes[0] != 0xFF ||
          bytes[1] != 0xD8 ||
          bytes[2] != 0xFF) {
        throw ArgumentError('FAIL-FAST: Firma binaria no corresponde a una imagen JPEG legítima.');
      }
    } else if (ext == 'png') {
      if (bytes.length < 4 ||
          bytes[0] != 0x89 ||
          bytes[1] != 0x50 ||
          bytes[2] != 0x4E ||
          bytes[3] != 0x47) {
        throw ArgumentError('FAIL-FAST: Firma binaria no corresponde a una imagen PNG legítima.');
      }
    } else if (ext == 'tif' || ext == 'tiff') {
      final isLittleEndian = bytes.length >= 4 &&
          bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00;
      final isBigEndian = bytes.length >= 4 &&
          bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A;
      if (!isLittleEndian && !isBigEndian) {
        throw ArgumentError('FAIL-FAST: Firma binaria no corresponde a una imagen TIFF legítima.');
      }
    }
  }
}
