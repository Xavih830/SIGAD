import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckSession extends AuthEvent {}

class LoginSubmitted extends AuthEvent {
  final String identificador;
  final String password;

  const LoginSubmitted({required this.identificador, required this.password});

  @override
  List<Object?> get props => [identificador, password];
}

class LogoutRequested extends AuthEvent {}

class ResetLockout extends AuthEvent {}

class ActivationSubmitted extends AuthEvent {
  final String identificacion;
  final String codigoOtp;
  final String password;
  final String passwordConfirmacion;
  final String? email;

  const ActivationSubmitted({
    required this.identificacion,
    required this.codigoOtp,
    required this.password,
    required this.passwordConfirmacion,
    this.email,
  });

  @override
  List<Object?> get props => [identificacion, codigoOtp, password, passwordConfirmacion, email];
}
