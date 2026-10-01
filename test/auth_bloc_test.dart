import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sigad/core/services/hive_helper.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'helpers/test_fixtures.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late AuthBloc authBloc;
  late MockHttpClient mockClient;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sigad_hive_test_dir');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveHelper.sessionBoxName);

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

  test('Initial state should be AuthInitial', () {
    expect(authBloc.state, equals(AuthInitial()));
  });

  test('CheckSession should emit AuthInitial when no session is cached', () async {
    authBloc.add(CheckSession());
    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthInitial(),
      ]),
    );
  });

  test('CheckSession should emit AuthSuccess when active user is cached in sessionBox', () async {
    await HiveHelper.sessionBox.put('active_user', TestFixtures.adminUserJson);

    authBloc.add(CheckSession());
    await expectLater(
      authBloc.stream,
      emitsInOrder([
        isA<AuthSuccess>().having((s) => s.user.email, 'email', TestFixtures.adminUser.email),
      ]),
    );
  });

  test('LoginSubmitted should emit AuthSuccess when valid admin credentials are provided', () async {
    when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
          TestFixtures.authSuccessResponseBody(),
          200,
        ));

    authBloc.add(const LoginSubmitted(
      identificador: TestFixtures.adminEmail,
      password: TestFixtures.adminPassword,
    ));

    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        isA<AuthSuccess>().having((s) => s.user.email, 'email', TestFixtures.adminUser.email),
      ]),
    );
  });

  test('LoginSubmitted should emit AuthFailure on wrong password', () async {
    when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
          TestFixtures.errorDetailBody(TestFixtures.invalidCredentialsDetail),
          401,
        ));

    authBloc.add(const LoginSubmitted(identificador: TestFixtures.adminEmail, password: TestFixtures.wrongPassword));

    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        const AuthFailure(message: TestFixtures.invalidCredentialsMessage),
      ]),
    );
  });

  test('LoginSubmitted should emit AuthFailure on network error without fallback', () async {
    when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenThrow(const SocketException('Failed host lookup'));

    authBloc.add(const LoginSubmitted(identificador: TestFixtures.adminEmail, password: TestFixtures.adminPassword));

    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        const AuthFailure(message: TestFixtures.serverErrorMessage),
      ]),
    );
  });

  test('LoginSubmitted should lock out user after 3 consecutive failures', () async {
    when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
          TestFixtures.errorDetailBody(TestFixtures.invalidCredentialsDetail),
          401,
        ));

    // Attempt 1
    authBloc.add(const LoginSubmitted(identificador: TestFixtures.adminEmail, password: TestFixtures.wrongPassword1));
    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        const AuthFailure(message: TestFixtures.invalidCredentialsMessage),
      ]),
    );

    // Attempt 2
    authBloc.add(const LoginSubmitted(identificador: TestFixtures.adminEmail, password: TestFixtures.wrongPassword2));
    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        const AuthFailure(message: TestFixtures.invalidCredentialsMessage),
      ]),
    );

    // Attempt 3
    authBloc.add(const LoginSubmitted(identificador: TestFixtures.adminEmail, password: TestFixtures.wrongPassword3));
    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        isA<AuthLockedOut>(),
      ]),
    );
  });

  group('ActivationSubmitted', () {
    test('should emit AuthSuccess and store session when activation succeeds', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            TestFixtures.activationSuccessResponseBody(),
            200,
          ));

      authBloc.add(const ActivationSubmitted(
        identificacion: TestFixtures.validCedula,
        codigoOtp: TestFixtures.validOtp,
        password: TestFixtures.validPassword,
        passwordConfirmacion: TestFixtures.validPassword,
        email: TestFixtures.clientEmail,
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          AuthLoading(),
          isA<AuthSuccess>().having((s) => s.user.email, 'email', TestFixtures.clientEmail),
        ]),
      );

      final stored = HiveHelper.sessionBox.get('active_user') as Map;
      expect(stored['rol'], equals('cliente'));
      expect(stored['access_token'], equals(TestFixtures.activationToken));
    });

    test('should emit AuthFailure when backend rejects vinculacion', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            TestFixtures.errorDetailBody(TestFixtures.otpInvalidDetail),
            400,
          ));

      authBloc.add(const ActivationSubmitted(
        identificacion: TestFixtures.validCedula,
        codigoOtp: TestFixtures.invalidOtp,
        password: TestFixtures.validPassword,
        passwordConfirmacion: TestFixtures.validPassword,
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          AuthLoading(),
          const AuthFailure(message: TestFixtures.otpInvalidDetail),
        ]),
      );
    });

    test('should emit AuthFailure on network error during activation', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenThrow(const SocketException('Connection reset by peer'));

      authBloc.add(const ActivationSubmitted(
        identificacion: TestFixtures.validCedula,
        codigoOtp: TestFixtures.validOtp,
        password: TestFixtures.validPassword,
        passwordConfirmacion: TestFixtures.validPassword,
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          AuthLoading(),
          isA<AuthFailure>().having((f) => f.message, 'message', contains('No se pudo conectar con el servidor')),
        ]),
      );
    });
  });

  group('Tipado Estricto de AuthState', () {
    test('AuthSuccess almacena y expone un UserModel fuertemente tipado', () {
      final user = TestFixtures.adminUser;

      final state = AuthSuccess(token: TestFixtures.validToken, user: user);
      expect(state.user.id, equals(user.id));
      expect(state.user.role, equals(user.role));
      expect(state.user.name, equals(user.name));
      expect(state.user.isActive, equals(user.isActive));
      expect(state.token, equals(TestFixtures.validToken));
    });

    test('AuthSuccess props incluye token y user para Equatable', () {
      final user = TestFixtures.clientUser;
      final state = AuthSuccess(token: TestFixtures.validToken, user: user);
      expect(state.props, equals([TestFixtures.validToken, user]));
    });
  });
}

