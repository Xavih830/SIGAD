import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';

class LockoutView extends StatefulWidget {
  final DateTime unlockTime;

  const LockoutView({super.key, required this.unlockTime});

  @override
  State<LockoutView> createState() => _LockoutViewState();
}

class _LockoutViewState extends State<LockoutView> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateRemaining();
    });
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    if (now.isAfter(widget.unlockTime)) {
      _timer?.cancel();
      if (mounted) {
        context.read<AuthBloc>().add(ResetLockout());
      }
    } else {
      if (mounted) {
        setState(() {
          _remaining = widget.unlockTime.difference(now);
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWebLandscape = kIsWeb && size.width >= 768;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: isWebLandscape ? 450 : double.infinity,
          decoration: isWebLandscape
              ? BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderLight, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                )
              : null,
          padding: EdgeInsets.symmetric(
            horizontal: isWebLandscape ? 40.0 : 16.0,
            vertical: isWebLandscape ? 50.0 : 20.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.lock_clock,
                size: 80,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Acceso Bloqueado',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Has superado el número máximo de intentos fallidos. Por seguridad, el acceso ha sido bloqueado temporalmente por 5 minutos.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMuted,
                    ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Podrás intentar de nuevo en:',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(_remaining),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.errorColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  context.read<AuthBloc>().add(ResetLockout());
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Volver a intentar',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
