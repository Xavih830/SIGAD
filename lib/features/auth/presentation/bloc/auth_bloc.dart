import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/constants/app_constants.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/services/session_vault.dart';
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
    on<ActivationSubmitted>(_onActivationSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<SessionExpired>(_onSessionExpired);
    on<ResetLockout>(_onResetLockout);
  }

  Future<void> _onCheckSession(CheckSession event, Emitter<AuthState> emit) async {
    final raw = await SessionVault.getSession();
    if (raw != null) {
      final token = raw['access_token'] as String?;
      if (token != null && token.isNotEmpty) {
        final user = UserModel.fromJson(raw);
        if (user.isActive) {
          emit(AuthSuccess(token: token, user: user));
          return;
        }
      }
      await SessionVault.clearSession();
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
        Uri.parse('${ApiConfig.baseUrl}${ApiEndpoints.authLogin}'),
        headers: ApiConfig.authHeaders(null),
        body: jsonEncode({
          'identificador': event.identificador.trim(),
          'password': event.password,
        }),
      ).timeout(AppConstants.apiDefaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String;
        final userMap = data['user'] as Map<String, dynamic>;

        final enriched = {
          ...userMap,
          'access_token': token,
          'refresh_token': data['refresh_token'],
        };

        final user = UserModel.fromJson(enriched);

        _failedAttempts = 0;
        _lockoutUntil = null;
        await SessionVault.clearSession();
        await SessionVault.saveSession(enriched);
        emit(AuthSuccess(token: token, user: user));
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

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    await SessionVault.clearSession();
    emit(AuthInitial());
  }

  Future<void> _onSessionExpired(SessionExpired event, Emitter<AuthState> emit) async {
    await SessionVault.clearSession();
    emit(AuthInitial());
  }

  void _onResetLockout(ResetLockout event, Emitter<AuthState> emit) {
    _failedAttempts = 0;
    _lockoutUntil = null;
    emit(AuthInitial());
  }

  Future<void> _onActivationSubmitted(
    ActivationSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiEndpoints.authVinculacion}'),
        headers: ApiConfig.authHeaders(null),
        body: jsonEncode({
          'identificacion': event.identificacion.trim(),
          'codigo_otp': event.codigoOtp.trim(),
          'password': event.password,
          'password_confirmacion': event.passwordConfirmacion,
          if (event.email != null && event.email!.trim().isNotEmpty)
            'email': event.email!.trim(),
        }),
      ).timeout(AppConstants.apiDefaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String;
        final userMap = data['user'] as Map<String, dynamic>;

        final enriched = {
          ...userMap,
          'access_token': token,
          'refresh_token': data['refresh_token'],
        };

        final user = UserModel.fromJson(enriched);

        _failedAttempts = 0;
        _lockoutUntil = null;
        await SessionVault.clearSession();
        await SessionVault.saveSession(enriched);
        emit(AuthSuccess(token: token, user: user));
      } else {
        final body = jsonDecode(response.body);
        final msg = (body is Map && body.containsKey('detail'))
            ? body['detail']
            : 'Error en la activación de la cuenta.';
        emit(AuthFailure(message: msg.toString()));
      }
    } catch (e) {
      emit(AuthFailure(message: 'No se pudo conectar con el servidor: $e'));
    }
  }

  @override
  Future<void> close() {
    _client.close();
    return super.close();
  }
}
