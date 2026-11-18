import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/date_formatter.dart';
import 'package:sigad/core/utils/print/policy_certificate_html_generator.dart';
import 'package:sigad/core/utils/print/print_helper.dart';

class PolicyCertificateDialog extends StatelessWidget {
  final PolicyModel policy;
  final String? clientName;

  const PolicyCertificateDialog({
    super.key,
    required this.policy,
    this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    final veh = policy.vehicle;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 750,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: const [
                      Icon(Icons.verified_outlined, color: AppTheme.primaryColor),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Certificado Formal de Póliza Vehicular',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        if (kIsWeb) {
                          final html = PolicyCertificateHtmlGenerator.generate(
                            policy: policy,
                            clientName: clientName,
                          );
                          triggerPrint(htmlContent: html);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Impresión disponible en navegador Web.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Imprimir / Guardar PDF'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Membrete corporativo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.shield, color: Colors.white, size: 30),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SIGAD SEGUROS S.A.',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      Text('RUC: 1792345678001 • Matriz Quito - Ecuador', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                      Text('PBX: (02) 2999-000 • contacto@sigadseguros.com.ec', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'PÓLIZA N° ${policy.number}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Estado: ${policy.status.toUpperCase()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Identificación del contrato
                      const Text(
                        'CERTIFICADO DE COBERTURA VEHICULAR',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 16),

                      // Datos de asegurado y vigencia
                      _buildHeaderBox('1. DATOS CONTRACTUALES Y VIGENCIA'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _itemRow('Titular / Cliente ID:', policy.clientId),
                                  _itemRow('Inicio Vigencia:', DateFormatter.toIsoDate(policy.startDate)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _itemRow('Emisión Kilometraje:', '${policy.emissionMileage} KM'),
                                  _itemRow('Fin Vigencia:', DateFormatter.toIsoDate(policy.endDate)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Datos del vehículo asegurado
                      _buildHeaderBox('2. ESPECIFICACIONES DEL VEHÍCULO ASEGURADO'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _itemRow('Placa de Rodaje:', veh?.plate ?? 'S/P'),
                                  _itemRow('Marca / Fabricante:', veh?.brand ?? 'No especificada'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _itemRow('Modelo:', veh?.model ?? 'No especificado'),
                                  _itemRow('Año de Fabricación:', veh != null ? '${veh.year}' : 'N/A'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Campos específicos del esquema si existen
                      if (policy.camposAdicionales != null && policy.camposAdicionales!.isNotEmpty) ...[
                        _buildHeaderBox('3. ESPECIFICACIONES TÉCNICAS ADICIONALES (ESQUEMA VEHICULAR)'),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Wrap(
                            spacing: 24,
                            runSpacing: 8,
                            children: policy.camposAdicionales!.entries.map((e) {
                              final displayKey = e.key.split('_').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
                              return SizedBox(
                                width: 280,
                                child: _itemRow('$displayKey:', e.value is bool ? (e.value ? 'SÍ' : 'NO') : '${e.value}'),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Cuadro de Coberturas y Valores Económicos
                      _buildHeaderBox('4. CONDICIONES ECONÓMICAS Y COBERTURAS'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _itemRow('Valor Asegurado Comercial:', '\$ ${policy.insuredValue.toStringAsFixed(2)} USD'),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _itemRow('Prima Neta Mensual:', '\$ ${policy.monthlyPremium.toStringAsFixed(2)} USD'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Coberturas Contratadas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: policy.coverages.map((c) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text('✔ ${c.nombre}', style: const TextStyle(fontSize: 11)),
                                )).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Deducibles
                      if (policy.deductibles.isNotEmpty) ...[
                        _buildHeaderBox('5. DEDUCIBLES CONTRATADOS'),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Column(
                            children: policy.deductibles.map((d) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('• ${d.tipoSiniestro.toUpperCase()}', style: const TextStyle(fontSize: 12)),
                                  Text('${d.porcentajeValor}% (Mínimo \$${d.montoMinimoUsd.toStringAsFixed(2)} USD)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Firmas de formalidad
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Container(width: 180, height: 1, color: Colors.black54),
                              const SizedBox(height: 4),
                              const Text('Asegurador / Emisor Autorizado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              const Text('SIGAD Seguros S.A.', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                            ],
                          ),
                          Column(
                            children: [
                              Container(width: 180, height: 1, color: Colors.black54),
                              const SizedBox(height: 4),
                              const Text('Asegurado / Titular', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              const Text('Conformidad Contractual', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Documento oficial emitido conforme a las regulaciones de la Superintendencia de Compañías, Valores y Seguros.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBox(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _itemRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$label ', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

