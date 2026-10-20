import 'dart:typed_data';
import 'package:sigad/core/utils/file_downloader_stub.dart'
    if (dart.library.js_interop) 'package:sigad/core/utils/file_downloader_web.dart';

class FileDownloaderHelper {
  static void download({required Uint8List bytes, required String filename}) {
    downloadBytes(bytes, filename);
  }
}
