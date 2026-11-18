import 'package:flutter/material.dart';
import 'package:sigad/core/routing/app_routes.dart';
import 'package:sigad/core/routing/auth_guard.dart';
import 'package:sigad/core/security/app_capability.dart';
import 'package:sigad/features/auth/presentation/pages/account_activation_page.dart';
import 'package:sigad/features/auth/presentation/pages/login_page.dart';
import 'package:sigad/features/mobile_client/presentation/pages/mobile_dashboard_page.dart';
import 'package:sigad/features/mobile_client/presentation/pages/splash_screen.dart';
import 'package:sigad/features/web_dashboard/presentation/pages/web_dashboard_page.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SplashScreen(),
        );
      case AppRoutes.login:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginPage(),
        );
      case AppRoutes.activacion:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AccountActivationPage(),
        );
      case AppRoutes.dashboard:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AuthGuard(
            capability: AppCapability.accessWebDashboard,
            builder: (user) => WebDashboardPage(user: user),
          ),
        );
      case AppRoutes.mobile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => AuthGuard(
            capability: AppCapability.accessMobileApp,
            builder: (user) => MobileDashboardPage(user: user),
          ),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginPage(),
        );
    }
  }
}
