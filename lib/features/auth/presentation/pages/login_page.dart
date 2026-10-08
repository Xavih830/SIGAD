import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/security/app_capability.dart';
import 'package:sigad/core/security/authorization_policy.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/sigad_logo.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_state.dart';
import 'package:sigad/features/auth/presentation/pages/account_activation_page.dart';
import 'package:sigad/features/auth/presentation/widgets/lockout_view.dart';
import 'package:sigad/features/mobile_client/presentation/pages/mobile_dashboard_page.dart';
import 'package:sigad/features/web_dashboard/presentation/pages/web_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            LoginSubmitted(identificador: _idCtrl.text, password: _passCtrl.text),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWebLandscape = kIsWeb && MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            final dashboard = AuthorizationPolicy.canUser(state.user, AppCapability.accessWebDashboard)
                ? WebDashboardPage(user: state.user)
                : MobileDashboardPage(user: state.user);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => dashboard),
            );
          }
        },
        builder: (context, state) {
          if (state is AuthLockedOut) {
            return LockoutView(unlockTime: state.unlockTime);
          }

          final isLoading = state is AuthLoading;
          final errorMsg = state is AuthFailure ? state.message : null;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: isWebLandscape ? 450 : double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isWebLandscape ? 40.0 : 16.0,
                  vertical: isWebLandscape ? 40.0 : 20.0,
                ),
                decoration: isWebLandscape
                    ? BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      )
                    : null,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: SigadLogo(size: 100, textColor: AppTheme.primaryColor)),
                      const SizedBox(height: 16),
                      Text('Iniciar Sesión', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                      const SizedBox(height: 8),
                      Text('Ingresa tus credenciales para acceder a SIGAD\n(correo electrónico o cédula)', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted)),
                      const SizedBox(height: 24),
                      if (errorMsg != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppTheme.errorColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3))),
                          child: Row(children: [const Icon(Icons.error_outline, color: AppTheme.errorColor), const SizedBox(width: 12), Expanded(child: Text(errorMsg, style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w600, fontSize: 13)))]),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _idCtrl,
                        decoration: const InputDecoration(labelText: 'Correo o Cédula', hintText: 'ej. admin@sigad.ec o 0926687856', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu identificador' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Ingresar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        key: const Key('goto_activation_button'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AccountActivationPage()),
                          );
                        },
                        child: const Text(
                          '¿Recibiste un código de vinculación por WhatsApp o correo?\nActiva tu cuenta aquí',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
