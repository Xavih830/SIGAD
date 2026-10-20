import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/widgets/backend_error_banner.dart';

void main() {
  setUp(() {
    ApiConfig.setBaseUrlForTesting('http://127.0.0.1:8000');
  });

  Widget createWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('BackendErrorBanner Tests', () {
    testWidgets('Muestra alerta simple para errores de negocio comunes', (tester) async {
      await tester.pumpWidget(
        createWidget(
          const BackendErrorBanner(errorMessage: 'Credenciales inválidas'),
        ),
      );

      expect(find.text('Credenciales inválidas'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('No se pudo conectar con el servidor backend'), findsNothing);
    });

    testWidgets('Muestra banner diagnóstico completo ante error de conexión con el servidor', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        createWidget(
          BackendErrorBanner(
            errorMessage: 'Error de conexión con el servidor',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('No se pudo conectar con el servidor backend'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.textContaining('docker compose up'), findsOneWidget);
      expect(find.textContaining('--web-port=8085'), findsOneWidget);
      expect(find.text('Comprobar backend'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      expect(retried, isTrue);
    });
  });
}
