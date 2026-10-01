import 'package:sigad/core/utils/file_picker_stub.dart'
    if (dart.library.html) 'package:sigad/core/utils/file_picker_web.dart';
import 'package:sigad/core/utils/file_picker_stub.dart' show SelectedFileInfo;

export 'package:sigad/core/utils/file_picker_stub.dart' show SelectedFileInfo;

class FilePickerHelper {
  static Future<SelectedFileInfo?> pickDocumentFile() =>
      FilePickerPlatform.pickDocumentFile();
}

