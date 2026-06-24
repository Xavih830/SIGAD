import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sigad_logo.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/auth/presentation/pages/login_page.dart';
import 'package:sigad/features/web_dashboard/presentation/pages/web_dashboard_page.dart';
import 'package:sigad/features/mobile_client/presentation/pages/mobile_dashboard_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    // Fade in animation
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });

    // Check session after at least 2 seconds (minimum visibility)
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        context.read<AuthBloc>().add(CheckSession());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = 130.0;

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            // Already logged in
            _navigateToDashboard(state.user);
          } else if (state is AuthInitial || state is AuthFailure || state is AuthLockedOut) {
            // Navigate to login
            _navigateToLogin();
          }
        },
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 800),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SigadLogo(size: logoSize),
                SizedBox(height: logoSize), // Distance equal to logo height
                const SizedBox(
                  height: 36,
                  width: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDashboard(Map<String, dynamic> user) {
    final route = PageRouteBuilder(
      pageBuilder: (c, a1, a2) {
        final role = user['role'];
        if (role == 'admin_system' || role == 'admin_rjseguros') {
          return WebDashboardPage(user: user);
        } else {
          return MobileDashboardPage(user: user);
        }
      },
      transitionsBuilder: (c, anim, a2, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    );
    Navigator.of(context).pushReplacement(route);
  }

  void _navigateToLogin() {
    final route = PageRouteBuilder(
      pageBuilder: (c, a1, a2) => const LoginPage(),
      transitionsBuilder: (c, anim, a2, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    );
    Navigator.of(context).pushReplacement(route);
  }
}
