import 'dart:typed_data';
import 'package:sigad/core/utils/file_downloader_stub.dart'
    if (dart.library.html) 'package:sigad/core/utils/file_downloader_web.dart';

/// Helper multiplataforma para descarga de archivos binarios sin acoplamiento a dart:html.
class FileDownloaderHelper {
  static void download({required Uint8List bytes, required String filename}) {
    downloadBytes(bytes, filename);
  }
}
