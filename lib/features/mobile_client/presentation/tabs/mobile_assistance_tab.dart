import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/models/catalog_model.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';

class MobileAssistanceTab extends StatefulWidget {
  const MobileAssistanceTab({super.key});

  @override
  State<MobileAssistanceTab> createState() => _MobileAssistanceTabState();
}

class _MobileAssistanceTabState extends State<MobileAssistanceTab> {
  late Future<List<AssistanceModel>> _assistancesFuture;

  @override
  void initState() {
    super.initState();
    _loadAssistances();
  }

  void _loadAssistances() {
    setState(() {
      _assistancesFuture = _fetchAssistances();
    });
  }

  Future<List<AssistanceModel>> _fetchAssistances() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/asistencias');
    final response = await http.get(uri).timeout(ApiConfig.defaultTimeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => AssistanceModel.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Error al consultar catálogo de asistencias (${response.statusCode})');
    }
  }

  Future<void> _makeCall(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+|-'), '');
    final url = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar llamada a $phone')),
        );
      }
    }
  }

  IconData _getIcon(String? iconName) {
    switch (iconName) {
      case 'local_shipping':
        return Icons.local_shipping;
      case 'build':
        return Icons.build;
      case 'explore':
        return Icons.explore;
      case 'emergency':
        return Icons.emergency;
      default:
        return Icons.phone;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AssistanceModel>>(
      future: _assistancesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ErrorView(
            message: 'No se pudieron cargar los servicios de asistencia: ${snapshot.error}',
            onRetry: _loadAssistances,
          );
        }

        final items = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'Números de Emergencia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Presiona sobre cualquiera de los servicios para llamar de inmediato.',
              style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No hay asistencias configuradas'),
                ),
              )
            else
              ...items.map((item) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.errorColor.withOpacity(0.1),
                      child: Icon(_getIcon(item.icon), color: AppTheme.errorColor),
                    ),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.description.isNotEmpty) ...[
                          Text(item.description, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          const SizedBox(height: 4),
                        ],
                        Text(item.emergencyPhone, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                      ],
                    ),
                    trailing: const Icon(Icons.phone_in_talk, color: AppTheme.primaryColor),
                    onTap: () => _makeCall(context, item.emergencyPhone),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
