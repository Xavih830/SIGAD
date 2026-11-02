import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_schema_model.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/dynamic_policy_form.dart';

class PolicySchemaSelectorSection extends StatelessWidget {
  final GlobalKey<DynamicPolicyFormState> dynamicFormKey;
  final bool isLoadingSchemas;
  final String? selectedSchemaId;
  final List<PolicySchemaListItemModel> availableSchemas;
  final PolicySchemaModel? selectedSchemaDetail;
  final ValueChanged<String?> onSchemaSelected;
  final Map<String, dynamic> initialDynamicValues;

  const PolicySchemaSelectorSection({
    super.key,
    required this.dynamicFormKey,
    required this.isLoadingSchemas,
    required this.selectedSchemaId,
    required this.availableSchemas,
    required this.selectedSchemaDetail,
    required this.onSchemaSelected,
    required this.initialDynamicValues,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esquema de Campos de Póliza:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (isLoadingSchemas)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: selectedSchemaId,
              decoration: const InputDecoration(
                labelText: 'Seleccionar Esquema',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sin campos adicionales (Estándar básico)'),
                ),
                ...availableSchemas.map(
                  (s) => DropdownMenuItem<String?>(
                    value: s.id,
                    child: Text('${s.nombre} (v${s.version}) ${s.esActivo ? "[Activo]" : ""}'),
                  ),
                ),
              ],
              onChanged: onSchemaSelected,
            ),
          if (selectedSchemaDetail != null) ...[
            const SizedBox(height: 12),
            DynamicPolicyForm(
              key: dynamicFormKey,
              schema: selectedSchemaDetail!,
              initialValues: initialDynamicValues,
            ),
          ],
        ],
      ),
    );
  }
}
