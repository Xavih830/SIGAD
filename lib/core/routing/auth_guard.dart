import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/routing/app_routes.dart';
import 'package:sigad/core/security/app_capability.dart';
import 'package:sigad/core/security/authorization_policy.dart';
import 'package:sigad/core/widgets/error_view.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';

class AuthGuard extends StatelessWidget {
  final AppCapability capability;
  final Widget Function(UserModel) builder;

  const AuthGuard({
    super.key,
    required this.capability,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthSuccess) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (_) => false,
              );
            }
          });
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = state.user;
        if (!AuthorizationPolicy.canUser(user, capability)) {
          return const Scaffold(
            body: Center(
              child: ErrorView(
                message: 'Acceso denegado',
              ),
            ),
          );
        }

        return builder(user);
      },
    );
  }
}
