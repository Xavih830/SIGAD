import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:sigad/core/utils/file_picker_stub.dart';
export 'package:sigad/core/utils/file_picker_stub.dart' show SelectedFileInfo;

class FilePickerPlatform {
  static Future<SelectedFileInfo?> pickDocumentFile() {
    final completer = Completer<SelectedFileInfo?>();
    final uploadInput = html.FileUploadInputElement()
      ..accept = '.pdf,image/png,image/jpeg,image/tiff';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);

      reader.onLoadEnd.listen((e) {
        final result = reader.result;
        Uint8List? bytes;
        if (result is Uint8List) {
          bytes = result;
        } else if (result is ByteBuffer) {
          bytes = result.asUint8List();
        }
        if (bytes != null && !completer.isCompleted) {
          completer.complete(SelectedFileInfo(name: file.name, bytes: bytes));
        } else if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      reader.onError.listen((e) {
        if (!completer.isCompleted) completer.complete(null);
      });
    });

    return completer.future;
  }
}
