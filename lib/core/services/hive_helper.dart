import 'package:hive_flutter/hive_flutter.dart';

/// Gestor de almacenamiento local Hive.
///

/// Hive se utiliza únicamente para persistencia de sesión local (JWT y usuario activo).

class HiveHelper {
  static const String sessionBoxName = 'session';
  static const String usersBoxName = 'users';

  static Box get sessionBox => Hive.box(sessionBoxName);
  static Box get usersBox => Hive.box(usersBoxName);

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(sessionBoxName);
    await Hive.openBox(usersBoxName);
  }
}
