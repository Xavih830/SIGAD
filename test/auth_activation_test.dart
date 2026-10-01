import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sigad/core/services/hive_helper.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/pages/account_activation_page.dart';
import 'package:sigad/features/auth/presentation/pages/login_page.dart';
import 'package:sigad/features/mobile_client/presentation/pages/mobile_dashboard_page.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late AuthBloc authBloc;
  late MockHttpClient mockClient;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sigad_activation_test_dir');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveHelper.sessionBoxName);
    await HiveHelper.sessionBox.put('welcome_sent_cliente@personal.com', true);

    mockClient = MockHttpClient();
    authBloc = AuthBloc(client: mockClient);
  });

  tearDown(() async {
    await authBloc.close();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget createWidgetUnderTest(Widget child) {
    return BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('HU-01/HU-13: AccountActivationPage Widget Tests', () {
    testWidgets('Debe renderizar los campos del formulario de activacion correctamente', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest(const AccountActivationPage()));
      await tester.pumpAndSettle();

      expect(find.text('Activar Cuenta Móvil'), findsOneWidget);
      expect(find.text('Vinculación de Asegurado'), findsOneWidget);
      expect(find.byKey(const Key('cedula_field')), findsOneWidget);
      expect(find.byKey(const Key('otp_field')), findsOneWidget);
      expect(find.byKey(const Key('password_field')), findsOneWidget);
      expect(find.byKey(const Key('confirm_password_field')), findsOneWidget);
      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(find.byKey(const Key('activate_button')), findsOneWidget);
    });

    testWidgets('Debe rechazar cedula ecuatoriana invalida por Modulo 10', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest(const AccountActivationPage()));
      await tester.pumpAndSettle();

      // Cédula vacía
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa tu cédula'), findsOneWidget);

      // Cédula inválida bajo Módulo 10
      await tester.enterText(find.byKey(const Key('cedula_field')), '1234567890');
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text('Cédula ecuatoriana inválida (Módulo 10)'), findsOneWidget);
    });

    testWidgets('Debe rechazar codigo OTP menor a 6 digitos', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest(const AccountActivationPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('cedula_field')), '0926687856');
      await tester.enterText(find.byKey(const Key('otp_field')), '12345');
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa los 6 dígitos del código'), findsOneWidget);
    });

    testWidgets('Debe validar complejidad estricta de contrasena (>=12 caracteres, mayuscula, minuscula, digito, simbolo)', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest(const AccountActivationPage()));
      await tester.pumpAndSettle();

      // Menor a 12 caracteres
      await tester.enterText(find.byKey(const Key('password_field')), 'Corto1!');
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text('Debe tener al menos 12 caracteres'), findsOneWidget);

      // Sin mayúscula
      await tester.enterText(find.byKey(const Key('password_field')), 'sinmayuscula123!');
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text('Debe incluir al menos una mayúscula'), findsOneWidget);

      // Sin minúscula
      await tester.enterText(find.byKey(const Key('password_field')), 'SINMINUSCULA123!');
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text('Debe incluir al menos una minúscula'), findsOneWidget);

      // Sin número
      await tester.enterText(find.byKey(const Key('password_field')), 'SinNumerosPassword!');
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text('Debe incluir al menos un número'), findsOneWidget);

      // Sin símbolo especial
      await tester.enterText(find.byKey(const Key('password_field')), 'SinSimbolosEspeciales123');
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text('Debe incluir un símbolo especial'), findsOneWidget);
    });

    testWidgets('Debe validar que la confirmacion de contrasena coincida', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest(const AccountActivationPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('cedula_field')), '0926687856');
      await tester.enterText(find.byKey(const Key('otp_field')), '123456');
      await tester.enterText(find.byKey(const Key('password_field')), 'PasswordSeguro2026*');
      await tester.enterText(find.byKey(const Key('confirm_password_field')), 'OtraPassword2026*');
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });

    testWidgets('Debe enviar ActivationSubmitted con datos validos y navegar al dashboard', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) => Future.value(http.Response(
            jsonEncode({
              'access_token': 'jwt_mobile_client_token',
              'refresh_token': 'jwt_mobile_refresh',
              'user': {
                'id': 'cli-usr-100',
                'email': 'cliente@personal.com',
                'nombre': 'Carlos Mendoza',
                'rol': 'cliente',
                'is_active': true,
              },
            }),
            200,
          )));

      await tester.pumpWidget(createWidgetUnderTest(const AccountActivationPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('cedula_field')), '0926687856');
      await tester.enterText(find.byKey(const Key('otp_field')), '458921');
      await tester.enterText(find.byKey(const Key('password_field')), 'PasswordSeguro2026*');
      await tester.enterText(find.byKey(const Key('confirm_password_field')), 'PasswordSeguro2026*');
      await tester.enterText(find.byKey(const Key('email_field')), 'cliente@personal.com');

      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.byType(MobileDashboardPage), findsOneWidget);
    });

    testWidgets('Debe mostrar mensaje de error en pantalla cuando backend rechaza vinculacion', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) => Future.value(http.Response(
            jsonEncode({'detail': 'Código de vinculación inválido o expirado.'}),
            400,
          )));

      await tester.pumpWidget(createWidgetUnderTest(const AccountActivationPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('cedula_field')), '0926687856');
      await tester.enterText(find.byKey(const Key('otp_field')), '000000');
      await tester.enterText(find.byKey(const Key('password_field')), 'PasswordSeguro2026*');
      await tester.enterText(find.byKey(const Key('confirm_password_field')), 'PasswordSeguro2026*');

      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.text('Código de vinculación inválido o expirado.'), findsOneWidget);
    });

    testWidgets('Debe navegar desde LoginPage hacia AccountActivationPage mediante el enlace', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest(const LoginPage()));
      await tester.pumpAndSettle();

      final linkFinder = find.byKey(const Key('goto_activation_button'));
      expect(linkFinder, findsOneWidget);

      await tester.ensureVisible(linkFinder);
      await tester.tap(linkFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AccountActivationPage), findsOneWidget);
      expect(find.text('Vinculación de Asegurado'), findsOneWidget);
    });
  });
}
