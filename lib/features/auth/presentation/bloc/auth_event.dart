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
