import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sigad/core/services/hive_helper.dart';
import 'package:sigad/core/utils/sha256_helper.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';

void main() {
  late AuthBloc authBloc;
  late Directory tempDir;

  setUp(() async {
    // Setup a clean temporary directory for Hive database boxes
    tempDir = await Directory.systemTemp.createTemp('sigad_hive_test_dir');
    Hive.init(tempDir.path);

    // Open standard boxes
    await Hive.openBox(HiveHelper.usersBoxName);
    await Hive.openBox(HiveHelper.clientsBoxName);
    await Hive.openBox(HiveHelper.policiesBoxName);
    await Hive.openBox(HiveHelper.sessionBoxName);
    await Hive.openBox(HiveHelper.workshopsBoxName);
    await Hive.openBox(HiveHelper.assistanceBoxName);

    // Seed mock data
    await HiveHelper.seedDataIfNeeded();

    authBloc = AuthBloc();
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

  test('LoginSubmitted should emit AuthSuccess when valid admin credentials are provided', () async {
    authBloc.add(const LoginSubmitted(email: 'admin@sigad.ec', password: 'Admin#SIGAD24'));
    
    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        isA<AuthSuccess>().having((s) => s.user['email'], 'email', 'admin@sigad.ec'),
      ]),
    );
  });

  test('LoginSubmitted should emit AuthSuccess when valid client credentials are provided', () async {
    authBloc.add(const LoginSubmitted(email: 'c.perez@gmail.com', password: 'Carlos#2024'));

    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        isA<AuthSuccess>().having((s) => s.user['email'], 'email', 'c.perez@gmail.com'),
      ]),
    );
  });

  test('LoginSubmitted should emit AuthFailure on wrong password', () async {
    authBloc.add(const LoginSubmitted(email: 'admin@sigad.ec', password: 'WrongPassword'));

    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        const AuthFailure(message: 'Las credenciales ingresadas no son válidas.'),
      ]),
    );
  });

  test('LoginSubmitted should lock out user after 3 consecutive failures', () async {
    // Attempt 1
    authBloc.add(const LoginSubmitted(email: 'admin@sigad.ec', password: 'WrongPassword1'));
    // Attempt 2
    authBloc.add(const LoginSubmitted(email: 'admin@sigad.ec', password: 'WrongPassword2'));
    // Attempt 3
    authBloc.add(const LoginSubmitted(email: 'admin@sigad.ec', password: 'WrongPassword3'));

    await expectLater(
      authBloc.stream,
      emitsInOrder([
        AuthLoading(),
        const AuthFailure(message: 'Las credenciales ingresadas no son válidas.'),
        AuthLoading(),
        const AuthFailure(message: 'Las credenciales ingresadas no son válidas.'),
        AuthLoading(),
        isA<AuthLockedOut>(),
      ]),
    );
  });
}
