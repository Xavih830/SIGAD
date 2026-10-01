import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';

void main() {
  group('Tipado Estricto de AuthState', () {
    test('AuthSuccess almacena y expone un UserModel fuertemente tipado', () {
      const user = UserModel(
        id: 'usr-100',
        email: 'admin@sigad.ec',
        name: 'Administrador General',
        role: 'admin_system',
        isActive: true,
      );

      const state = AuthSuccess(token: 'mock-jwt-token', user: user);
      expect(state.user.id, equals('usr-100'));
      expect(state.user.role, equals('admin_system'));
      expect(state.user.name, equals('Administrador General'));
      expect(state.user.isActive, isTrue);
      expect(state.token, equals('mock-jwt-token'));
    });

    test('AuthSuccess props incluye token y user para Equatable', () {
      const user = UserModel(
        id: 'usr-200',
        email: 'agente@sigad.ec',
        name: 'Agente RJ',
        role: 'admin_rjseguros',
        isActive: true,
      );
      const state = AuthSuccess(token: 'tok-abc', user: user);
      expect(state.props, equals(['tok-abc', user]));
    });
  });
}
