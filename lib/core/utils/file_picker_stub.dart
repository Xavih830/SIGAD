import 'dart:typed_data';

class SelectedFileInfo {
  final String name;
  final Uint8List bytes;

  const SelectedFileInfo({required this.name, required this.bytes});
}

class FilePickerPlatform {
  static Future<SelectedFileInfo?> pickDocumentFile() async {
    return null;
  }
}
