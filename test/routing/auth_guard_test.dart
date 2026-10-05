import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/routing/app_router.dart';
import 'package:sigad/core/routing/auth_guard.dart';
import 'package:sigad/core/security/app_capability.dart';
import 'package:sigad/core/services/session_vault.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/auth/presentation/pages/login_page.dart';

class MockAuthBloc extends Mock implements AuthBloc {}

void main() {
  late MockAuthBloc mockAuthBloc;

  setUpAll(() {
    registerFallbackValue(CheckSession());
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    SessionVault.enableTestMode();
  });

  tearDown(() {
    SessionVault.resetTestMode();
  });

  Widget buildTestableApp({
    required Widget child,
  }) {
    return BlocProvider<AuthBloc>.value(
      value: mockAuthBloc,
      child: MaterialApp(
        navigatorKey: AppRouter.navigatorKey,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: child,
      ),
    );
  }

  testWidgets('Sin sesión, AuthGuard redirige a LoginPage', (tester) async {
    when(() => mockAuthBloc.state).thenReturn(AuthInitial());
    when(() => mockAuthBloc.stream).thenAnswer((_) => Stream.value(AuthInitial()));

    await tester.pumpWidget(
      buildTestableApp(
        child: AuthGuard(
          capability: AppCapability.accessWebDashboard,
          builder: (user) => const Text('Panel Administrativo'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Panel Administrativo'), findsNothing);
  });

  testWidgets('Con usuario sin capacidad, AuthGuard muestra Acceso denegado', (tester) async {
    const clientUser = UserModel(
      id: 'client-1',
      email: 'client@sigad.ec',
      name: 'Cliente Test',
      role: UserRole.cliente,
      isActive: true,
    );

    when(() => mockAuthBloc.state).thenReturn(
      const AuthSuccess(token: 'valid_token', user: clientUser),
    );
    when(() => mockAuthBloc.stream).thenAnswer(
      (_) => Stream.value(const AuthSuccess(token: 'valid_token', user: clientUser)),
    );

    await tester.pumpWidget(
      buildTestableApp(
        child: AuthGuard(
          capability: AppCapability.accessWebDashboard,
          builder: (user) => const Text('Panel Administrativo'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Acceso denegado'), findsOneWidget);
    expect(find.text('Panel Administrativo'), findsNothing);
  });

  testWidgets('Con usuario autorizado, AuthGuard renderiza el contenido protegido', (tester) async {
    const adminUser = UserModel(
      id: 'admin-1',
      email: 'admin@sigad.ec',
      name: 'Admin Test',
      role: UserRole.admin,
      isActive: true,
    );

    when(() => mockAuthBloc.state).thenReturn(
      const AuthSuccess(token: 'valid_token', user: adminUser),
    );
    when(() => mockAuthBloc.stream).thenAnswer(
      (_) => Stream.value(const AuthSuccess(token: 'valid_token', user: adminUser)),
    );

    await tester.pumpWidget(
      buildTestableApp(
        child: AuthGuard(
          capability: AppCapability.accessWebDashboard,
          builder: (user) => const Text('Panel Administrativo'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Panel Administrativo'), findsOneWidget);
    expect(find.text('Acceso denegado'), findsNothing);
  });
}
