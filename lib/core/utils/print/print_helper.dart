import 'package:sigad/core/utils/print/print_helper_stub.dart'
    if (dart.library.html) 'package:sigad/core/utils/print/print_helper_web.dart';

void triggerPrint() {
  triggerBrowserPrint();
}
