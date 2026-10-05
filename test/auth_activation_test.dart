import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sigad/core/services/session_vault.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/pages/account_activation_page.dart';
import 'package:sigad/features/auth/presentation/pages/login_page.dart';
import 'package:sigad/features/mobile_client/presentation/pages/mobile_dashboard_page.dart';
import 'helpers/test_fixtures.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late AuthBloc authBloc;
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() async {
    SessionVault.enableTestMode();
    await SessionVault.setFlag('welcome_sent_${TestFixtures.clientEmail}', true);

    mockClient = MockHttpClient();
    authBloc = AuthBloc(client: mockClient);
  });

  tearDown(() async {
    await authBloc.close();
    SessionVault.resetTestMode();
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
      expect(find.text(TestFixtures.cedulaRequiredMessage), findsOneWidget);

      // Cédula inválida bajo Módulo 10
      await tester.enterText(find.byKey(const Key('cedula_field')), TestFixtures.invalidCedulaModulo10);
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text(TestFixtures.cedulaInvalidModulo10), findsOneWidget);
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

      await tester.enterText(find.byKey(const Key('cedula_field')), TestFixtures.validCedula);
      await tester.enterText(find.byKey(const Key('otp_field')), TestFixtures.shortOtp);
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();

      expect(find.text(TestFixtures.otpLengthMessage), findsOneWidget);
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
      await tester.enterText(find.byKey(const Key('password_field')), TestFixtures.passwordTooShort);
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text(TestFixtures.passwordMinLength), findsOneWidget);

      // Sin mayúscula
      await tester.enterText(find.byKey(const Key('password_field')), TestFixtures.passwordMissingUpper);
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text(TestFixtures.passwordRequiresUpper), findsOneWidget);

      // Sin minúscula
      await tester.enterText(find.byKey(const Key('password_field')), TestFixtures.passwordMissingLower);
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text(TestFixtures.passwordRequiresLower), findsOneWidget);

      // Sin número
      await tester.enterText(find.byKey(const Key('password_field')), TestFixtures.passwordMissingDigit);
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text(TestFixtures.passwordRequiresNumber), findsOneWidget);

      // Sin símbolo especial
      await tester.enterText(find.byKey(const Key('password_field')), TestFixtures.passwordMissingSpecial);
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();
      expect(find.text(TestFixtures.passwordRequiresSpecial), findsOneWidget);
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

      await tester.enterText(find.byKey(const Key('cedula_field')), TestFixtures.validCedula);
      await tester.enterText(find.byKey(const Key('otp_field')), TestFixtures.validOtp);
      await tester.enterText(find.byKey(const Key('password_field')), TestFixtures.validPassword);
      await tester.enterText(find.byKey(const Key('confirm_password_field')), TestFixtures.mismatchedPassword);
      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.pumpAndSettle();

      expect(find.text(TestFixtures.passwordMismatchMessage), findsOneWidget);
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
            TestFixtures.activationSuccessResponseBody(),
            200,
          )));

      await tester.pumpWidget(createWidgetUnderTest(const AccountActivationPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('cedula_field')), TestFixtures.validCedula);
      await tester.enterText(find.byKey(const Key('otp_field')), TestFixtures.validOtp);
      await tester.enterText(find.byKey(const Key('password_field')), TestFixtures.validPassword);
      await tester.enterText(find.byKey(const Key('confirm_password_field')), TestFixtures.validPassword);
      await tester.enterText(find.byKey(const Key('email_field')), TestFixtures.clientEmail);

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
            TestFixtures.errorDetailBody(TestFixtures.otpInvalidDetail),
            400,
          )));

      await tester.pumpWidget(createWidgetUnderTest(const AccountActivationPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('cedula_field')), TestFixtures.validCedula);
      await tester.enterText(find.byKey(const Key('otp_field')), TestFixtures.invalidOtp);
      await tester.enterText(find.byKey(const Key('password_field')), TestFixtures.validPassword);
      await tester.enterText(find.byKey(const Key('confirm_password_field')), TestFixtures.validPassword);

      await tester.ensureVisible(find.byKey(const Key('activate_button')));
      await tester.tap(find.byKey(const Key('activate_button')));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.text(TestFixtures.otpInvalidDetail), findsOneWidget);
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
