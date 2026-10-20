import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void downloadBytes(Uint8List bytes, String filename) {
  final cleanFilename = filename.trim().isNotEmpty ? filename.trim() : 'documento.bin';

  String mimeType = 'application/octet-stream';
  final lower = cleanFilename.toLowerCase();
  if (lower.endsWith('.pdf')) {
    mimeType = 'application/pdf';
  } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    mimeType = 'image/jpeg';
  } else if (lower.endsWith('.png')) {
    mimeType = 'image/png';
  }

  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = cleanFilename;
  anchor.style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  // Delayed revoke so browser can initiate the download stream without losing metadata
  Future.delayed(const Duration(seconds: 15), () {
    web.URL.revokeObjectURL(url);
  });
}

