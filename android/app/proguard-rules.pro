# Reglas de Ofuscación y Reducción ProGuard / R8 para SIGAD
# Preservar bindings de Flutter Engine y Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# SharedPreferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }
