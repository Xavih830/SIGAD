import 'dart:typed_data';
import 'package:sigad/core/utils/file_downloader_stub.dart'
    if (dart.library.html) 'package:sigad/core/utils/file_downloader_web.dart';

class FileDownloaderHelper {
  static void download({required Uint8List bytes, required String filename}) {
    downloadBytes(bytes, filename);
  }
}
