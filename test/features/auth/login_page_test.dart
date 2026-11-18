import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/services/session_vault.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/auth/presentation/pages/login_page.dart';
import 'package:sigad/features/web_dashboard/presentation/pages/web_dashboard_page.dart';

class MockAuthBloc extends Mock implements AuthBloc {}

void main() {
  late MockAuthBloc mockAuthBloc;
  late StreamController<AuthState> stateController;

  setUpAll(() {
    registerFallbackValue(const LoginSubmitted(identificador: '', password: ''));
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    stateController = StreamController<AuthState>.broadcast();
    SessionVault.enableTestMode();

    when(() => mockAuthBloc.stream).thenAnswer((_) => stateController.stream);
    when(() => mockAuthBloc.state).thenReturn(AuthInitial());
  });

  tearDown(() async {
    await stateController.close();
    SessionVault.resetTestMode();
  });

  Widget buildTestableWidget() {
    return BlocProvider<AuthBloc>.value(
      value: mockAuthBloc,
      child: const MaterialApp(
        home: LoginPage(),
      ),
    );
  }

  testWidgets('Renderiza campos de identificador, password y boton ingresar', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Correo o Cédula'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Ingresar'), findsOneWidget);
  });

  testWidgets('Validacion de campos requeridos al presionar submit con formulario vacio', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu identificador'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    verifyNever(() => mockAuthBloc.add(any()));
  });

  testWidgets('Al presionar submit con credenciales, despacha LoginSubmitted a AuthBloc', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'admin@sigad.ec');
    await tester.enterText(find.byType(TextFormField).last, 'Password123#');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Ingresar'));
    await tester.pump();

    verify(() => mockAuthBloc.add(any(that: isA<LoginSubmitted>()))).called(1);
  });

  testWidgets('Al recibir estado AuthFailure, muestra mensaje de error en pantalla', (tester) async {
    when(() => mockAuthBloc.state).thenReturn(const AuthFailure(message: 'Credenciales inválidas. Verifique sus datos.'));

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(find.text('Credenciales inválidas. Verifique sus datos.'), findsOneWidget);
  });

  testWidgets('Al recibir estado AuthSuccess, navega al dashboard correspondiente', (tester) async {
    const adminUser = UserModel(
      id: 'admin-1',
      email: 'admin@sigad.ec',
      name: 'Admin Test',
      role: UserRole.admin,
      isActive: true,
    );

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    stateController.add(const AuthSuccess(token: 'valid_jwt_token', user: adminUser));
    await tester.pumpAndSettle();

    expect(find.byType(WebDashboardPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });
}
