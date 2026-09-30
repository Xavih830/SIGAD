import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/models/catalog_model.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/widgets/error_view.dart';

class MobileWorkshopsTab extends StatefulWidget {
  const MobileWorkshopsTab({super.key});

  @override
  State<MobileWorkshopsTab> createState() => _MobileWorkshopsTabState();
}

class _MobileWorkshopsTabState extends State<MobileWorkshopsTab> {
  late Future<List<WorkshopModel>> _workshopsFuture;

  @override
  void initState() {
    super.initState();
    _loadWorkshops();
  }

  void _loadWorkshops() {
    setState(() {
      _workshopsFuture = _fetchWorkshops();
    });
  }

  Future<List<WorkshopModel>> _fetchWorkshops() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/talleres');
    final response = await http.get(uri).timeout(ApiConfig.defaultTimeout);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => WorkshopModel.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Error al consultar red de talleres (${response.statusCode})');
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
          SnackBar(content: Text('No se pudo iniciar llamada al $phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WorkshopModel>>(
      future: _workshopsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ErrorView(
            message: 'No se pudieron cargar los talleres: ${snapshot.error}',
            onRetry: _loadWorkshops,
          );
        }

        final workshops = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'Red de Talleres Autorizados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Talleres mecánicos autorizados para atención y reparación de siniestros.',
              style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            if (workshops.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No hay talleres disponibles'),
                ),
              )
            else
              ...workshops.map((w) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.build_circle, color: AppTheme.primaryColor, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                w.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ciudad: ${w.city}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentColor,
                          ),
                        ),
                        const Divider(height: 18, color: AppTheme.borderLight),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                w.address,
                                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: w.phone.isNotEmpty ? () => _makeCall(context, w.phone) : null,
                          child: Row(
                            children: [
                              const Icon(Icons.phone_android_outlined, size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                w.phone,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.open_in_new, size: 12, color: AppTheme.primaryColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
