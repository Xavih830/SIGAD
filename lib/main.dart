import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/routing/app_router.dart';
import 'package:sigad/core/routing/app_routes.dart';
import 'package:sigad/core/services/notifications/notifications_manager.dart';
import 'package:sigad/core/services/session_vault.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionVault.init();
  await NotificationsManager.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            current is AuthSessionExpired ||
            (current is AuthInitial && previous is AuthSuccess),
        listener: (context, state) {
          AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            AppRoutes.login,
            (_) => false,
          );
          if (state is AuthSessionExpired) {
            final currentContext = AppRouter.navigatorKey.currentContext;
            if (currentContext != null) {
              ScaffoldMessenger.of(currentContext).showSnackBar(
                const SnackBar(
                  content: Text('Su sesión ha expirado.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        },
        child: MaterialApp(
          navigatorKey: AppRouter.navigatorKey,
          onGenerateRoute: AppRouter.onGenerateRoute,
          initialRoute: AppRoutes.splash,
          title: 'SIGAD - Gestión de Pólizas Vehiculares',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
        ),
      ),
    );
  }
}
