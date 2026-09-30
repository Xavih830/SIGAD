import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';

class MobileContactTab extends StatelessWidget {
  const MobileContactTab({super.key});

  Future<void> _makeCall(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+|-'), '');
    final url = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar llamada al $phone')),
        );
      }
    }
  }

  Future<void> _sendMail(BuildContext context, String email) async {
    final url = Uri.parse('mailto:$email?subject=Consulta SIGAD');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el correo para $email')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFFE7F5FF),
            child: Icon(Icons.business, color: AppTheme.primaryColor, size: 42),
          ),
        ),
        const SizedBox(height: 16),
        const Text('RJ Seguros', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
        const SizedBox(height: 4),
        const Text('Corredora de Seguros Vehiculares', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.phone, color: AppTheme.primaryColor),
                title: const Text('Llámanos', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                subtitle: const Text('04-2987654', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _makeCall(context, '04-2987654'),
              ),
              const Divider(height: 1, color: AppTheme.borderLight),
              ListTile(
                leading: const Icon(Icons.email, color: AppTheme.primaryColor),
                title: const Text('Escríbenos', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                subtitle: const Text('contacto@rjseguros.ec', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _sendMail(context, 'contacto@rjseguros.ec'),
              ),
              const Divider(height: 1, color: AppTheme.borderLight),
              const ListTile(
                leading: Icon(Icons.schedule, color: AppTheme.primaryColor),
                title: Text('Horario de Atención', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                subtitle: Text('Lunes a Viernes de 09:00 a 18:00', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => context.read<AuthBloc>().add(LogoutRequested()),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar Sesión'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor, padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      ],
    );
  }
}
