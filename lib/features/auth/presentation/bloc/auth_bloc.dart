import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/services/hive_helper.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final http.Client _client;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  AuthBloc({http.Client? client})
      : _client = client ?? http.Client(),
        super(AuthInitial()) {
    on<CheckSession>(_onCheckSession);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<ResetLockout>(_onResetLockout);
  }

  void _onCheckSession(CheckSession event, Emitter<AuthState> emit) {
    final activeUser = HiveHelper.sessionBox.get('active_user');
    if (activeUser != null) {
      final userMap = Map<String, dynamic>.from(activeUser);
      if (userMap['isActive'] != false) {
        emit(AuthSuccess(user: userMap));
        return;
      }
      HiveHelper.sessionBox.delete('active_user');
    }
    emit(AuthInitial());
  }

  Future<void> _onLoginSubmitted(LoginSubmitted event, Emitter<AuthState> emit) async {
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      emit(AuthLockedOut(unlockTime: _lockoutUntil!));
      return;
    }

    emit(AuthLoading());

    try {
      final response = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/login'),
        headers: ApiConfig.authHeaders(null),
        body: jsonEncode({
          'identificador': event.identificador.trim(),
          'password': event.password,
        }),
      ).timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>;

        final sessionData = {
          ...user,
          'access_token': data['access_token'],
          'refresh_token': data['refresh_token'],
          'role': _mapRol(user['rol'] ?? ''),
          'name': user['nombre'] ?? '',
          'email': user['email'] ?? '',
          'isActive': true,
        };

        _failedAttempts = 0;
        _lockoutUntil = null;
        await HiveHelper.sessionBox.put('active_user', sessionData);
        emit(AuthSuccess(user: sessionData));
      } else {
        _handleLoginFailure(emit);
      }
    } catch (e) {
      emit(const AuthFailure(message: 'Error de conexión con el servidor'));
    }
  }

  void _handleLoginFailure(Emitter<AuthState> emit) {
    _failedAttempts++;
    if (_failedAttempts >= 3) {
      _lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
      emit(AuthLockedOut(unlockTime: _lockoutUntil!));
    } else {
      emit(const AuthFailure(message: 'Las credenciales ingresadas no son válidas.'));
    }
  }

  String _mapRol(String backendRol) {
    switch (backendRol) {
      case 'admin':
        return 'admin_system';
      case 'agente':
        return 'admin_rjseguros';
      case 'cliente':
        return 'client';
      default:
        return backendRol;
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    await HiveHelper.sessionBox.delete('active_user');
    emit(AuthInitial());
  }

  void _onResetLockout(ResetLockout event, Emitter<AuthState> emit) {
    _failedAttempts = 0;
    _lockoutUntil = null;
    emit(AuthInitial());
  }

  @override
  Future<void> close() {
    _client.close();
    return super.close();
  }
}
