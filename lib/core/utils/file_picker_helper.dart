import 'package:sigad/core/utils/file_picker_stub.dart'
    if (dart.library.html) 'package:sigad/core/utils/file_picker_web.dart';

export 'package:sigad/core/utils/file_picker_stub.dart' show SelectedFileInfo;


class FilePickerHelper {
  static Future<SelectedFileInfo?> pickDocumentFile() =>
      FilePickerPlatform.pickDocumentFile();
}

