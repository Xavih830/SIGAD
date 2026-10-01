import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:sigad/core/services/hive_helper.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';

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
    await HiveHelper.sessionBox.put('active_user', {
      'id': 'usr-1',
      'email': 'admin@sigad.ec',
      'name': 'Admin',
      'role': 'admin_system',
      'isActive': true,
    });

    authBloc.add(CheckSession());
    await expectLater(
      authBloc.stream,
      emitsInOrder([
        isA<AuthSuccess>().having((s) => s.user['email'], 'email', 'admin@sigad.ec'),
      ]),
    );
  });

  test('LoginSubmitted should emit AuthSuccess when valid admin credentials are provided', () async {
    when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'access_token': 'jwt_mock_token',
            'refresh_token': 'jwt_refresh_mock',
            'user': {
              'id': 'usr-1',
              'email': 'admin@sigad.ec',
              'nombre': 'Administrador del Sistema',
              'rol': 'admin',
              'is_active': true,
            },
          }),
          200,
        ));

    authBloc.add(const LoginSubmitted(identificador: 'admin@sigad.ec', password: 'Admin#SIGAD24'));

    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        isA<AuthSuccess>().having((s) => s.user['email'], 'email', 'admin@sigad.ec'),
      ]),
    );
  });

  test('LoginSubmitted should emit AuthFailure on wrong password', () async {
    when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({'detail': 'Invalid credentials'}),
          401,
        ));

    authBloc.add(const LoginSubmitted(identificador: 'admin@sigad.ec', password: 'WrongPassword'));

    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        const AuthFailure(message: 'Las credenciales ingresadas no son válidas.'),
      ]),
    );
  });

  test('LoginSubmitted should emit AuthFailure on network error without fallback', () async {
    when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenThrow(const SocketException('Failed host lookup'));

    authBloc.add(const LoginSubmitted(identificador: 'admin@sigad.ec', password: 'AnyPassword'));

    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        const AuthFailure(message: 'Error de conexión con el servidor'),
      ]),
    );
  });

  test('LoginSubmitted should lock out user after 3 consecutive failures', () async {
    when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({'detail': 'Invalid credentials'}),
          401,
        ));

    // Attempt 1
    authBloc.add(const LoginSubmitted(identificador: 'admin@sigad.ec', password: 'WrongPassword1'));
    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        const AuthFailure(message: 'Las credenciales ingresadas no son válidas.'),
      ]),
    );

    // Attempt 2
    authBloc.add(const LoginSubmitted(identificador: 'admin@sigad.ec', password: 'WrongPassword2'));
    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        const AuthFailure(message: 'Las credenciales ingresadas no son válidas.'),
      ]),
    );

    // Attempt 3
    authBloc.add(const LoginSubmitted(identificador: 'admin@sigad.ec', password: 'WrongPassword3'));
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
            jsonEncode({
              'access_token': 'mock_activation_access_token',
              'refresh_token': 'mock_activation_refresh_token',
              'user': {
                'id': 'client-usr-1',
                'email': 'cliente@seguro.ec',
                'nombre': 'Juan Perez',
                'rol': 'cliente',
                'is_active': true,
              },
            }),
            200,
          ));

      authBloc.add(const ActivationSubmitted(
        identificacion: '0926687856',
        codigoOtp: '458921',
        password: 'PasswordSeguro2026*',
        passwordConfirmacion: 'PasswordSeguro2026*',
        email: 'cliente@seguro.ec',
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          AuthLoading(),
          isA<AuthSuccess>().having((s) => s.user['email'], 'email', 'cliente@seguro.ec'),
        ]),
      );

      final stored = HiveHelper.sessionBox.get('active_user') as Map;
      expect(stored['role'], equals('client'));
      expect(stored['access_token'], equals('mock_activation_access_token'));
    });

    test('should emit AuthFailure when backend rejects vinculacion', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({'detail': 'Código de vinculación inválido o expirado.'}),
            400,
          ));

      authBloc.add(const ActivationSubmitted(
        identificacion: '0926687856',
        codigoOtp: '000000',
        password: 'PasswordSeguro2026*',
        passwordConfirmacion: 'PasswordSeguro2026*',
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          AuthLoading(),
          const AuthFailure(message: 'Código de vinculación inválido o expirado.'),
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
        identificacion: '0926687856',
        codigoOtp: '458921',
        password: 'PasswordSeguro2026*',
        passwordConfirmacion: 'PasswordSeguro2026*',
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
}

