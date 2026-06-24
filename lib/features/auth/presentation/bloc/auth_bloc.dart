import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/hive_helper.dart';
import '../../../../core/utils/sha256_helper.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  AuthBloc() : super(AuthInitial()) {
    on<CheckSession>(_onCheckSession);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<ResetLockout>(_onResetLockout);
  }

  void _onCheckSession(CheckSession event, Emitter<AuthState> emit) {
    final activeUser = HiveHelper.sessionBox.get('active_user');
    if (activeUser != null) {
      final userMap = Map<String, dynamic>.from(activeUser);
      final freshUser = HiveHelper.usersBox.get(userMap['email']);
      if (freshUser != null) {
        final freshUserMap = Map<String, dynamic>.from(freshUser);
        if (freshUserMap['isActive'] == true) {
          emit(AuthSuccess(user: freshUserMap));
          return;
        }
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

    final email = event.email.trim().toLowerCase();
    final password = event.password;

    final user = HiveHelper.usersBox.get(email);
    if (user != null) {
      final userMap = Map<String, dynamic>.from(user);
      final hashedInput = Sha256Helper.hash(password);

      if (userMap['passwordHash'] == hashedInput) {
        if (userMap['isActive'] == true) {
          _failedAttempts = 0;
          _lockoutUntil = null;
          await HiveHelper.sessionBox.put('active_user', userMap);
          emit(AuthSuccess(user: userMap));
          return;
        } else {
          emit(const AuthFailure(message: 'La cuenta ingresada está inactiva.'));
          return;
        }
      }
    }

    _failedAttempts++;
    if (_failedAttempts >= 3) {
      _lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
      emit(AuthLockedOut(unlockTime: _lockoutUntil!));
    } else {
      emit(const AuthFailure(message: 'Las credenciales ingresadas no son válidas.'));
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
}
