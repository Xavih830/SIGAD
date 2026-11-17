import 'package:sigad/core/utils/print/print_helper_stub.dart'
    if (dart.library.js_interop) 'package:sigad/core/utils/print/print_helper_web.dart';

void triggerPrint({String? htmlContent}) {
  triggerBrowserPrint(htmlContent);
}
