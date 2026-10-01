import 'package:hive_flutter/hive_flutter.dart';

/// Gestor de almacenamiento local Hive.
///
/// Hive se utiliza EXCLUSIVAMENTE para persistir el token de sesión (JWT)
/// en el almacenamiento local seguro del dispositivo o navegador.
class HiveHelper {
  static const String sessionBoxName = 'session';

  static Box get sessionBox => Hive.box(sessionBoxName);

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(sessionBoxName);
  }
}
