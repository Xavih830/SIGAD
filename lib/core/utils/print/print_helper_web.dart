import 'dart:js_interop';

import 'package:web/web.dart' as web;

void triggerBrowserPrint([String? htmlContent]) {
  if (htmlContent == null || htmlContent.trim().isEmpty) {
    web.window.print();
    return;
  }

  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
  iframe.style.position = 'fixed';
  iframe.style.right = '0';
  iframe.style.bottom = '0';
  iframe.style.width = '0';
  iframe.style.height = '0';
  iframe.style.border = '0';
  iframe.style.opacity = '0';
  iframe.style.pointerEvents = 'none';

  web.document.body?.append(iframe);

  var printed = false;
  void doPrint() {
    if (printed) return;
    printed = true;
    try {
      iframe.contentWindow?.focus();
      iframe.contentWindow?.print();
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        iframe.remove();
      });
    }
  }

  iframe.onload = ((web.Event _) {
    doPrint();
  }).toJS;

  iframe.srcdoc = htmlContent.toJS;

  Future.delayed(const Duration(milliseconds: 300), () {
    doPrint();
  });
}
