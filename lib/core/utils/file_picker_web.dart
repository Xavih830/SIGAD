import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:sigad/core/utils/file_picker_stub.dart';
import 'package:web/web.dart' as web;

export 'package:sigad/core/utils/file_picker_stub.dart' show SelectedFileInfo;

class FilePickerPlatform {
  static Future<SelectedFileInfo?> pickDocumentFile() {
    final completer = Completer<SelectedFileInfo?>();
    final uploadInput = web.document.createElement('input') as web.HTMLInputElement;
    uploadInput.type = 'file';
    uploadInput.accept = '.pdf,image/png,image/jpeg,image/tiff';
    uploadInput.click();

    uploadInput.onchange = ((web.Event e) {
      final files = uploadInput.files;
      if (files == null || files.length == 0) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final file = files.item(0);
      if (file == null) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final reader = web.FileReader();
      reader.readAsArrayBuffer(file);

      reader.onloadend = ((web.ProgressEvent event) {
        final result = reader.result;
        Uint8List? bytes;
        if (result != null && result.isA<JSArrayBuffer>()) {
          final buffer = result as JSArrayBuffer;
          bytes = buffer.toDart.asUint8List();
        }
        if (bytes != null && !completer.isCompleted) {
          completer.complete(SelectedFileInfo(name: file.name, bytes: bytes));
        } else if (!completer.isCompleted) {
          completer.complete(null);
        }
      }).toJS;

      reader.onerror = ((web.ProgressEvent event) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS;
    }).toJS;

    return completer.future;
  }
}
