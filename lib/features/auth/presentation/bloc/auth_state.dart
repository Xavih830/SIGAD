import 'package:equatable/equatable.dart';
import 'package:sigad/core/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String token;
  final UserModel user; //  TIPADO FUERTE: Ya no es Map<String, dynamic>

  const AuthSuccess({required this.token, required this.user});

  @override
  List<Object?> get props => [token, user];
}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

class AuthLockedOut extends AuthState {
  final DateTime unlockTime;

  const AuthLockedOut({required this.unlockTime});

  @override
  List<Object?> get props => [unlockTime];
}
