import 'package:flutter/material.dart';
import 'package:sigad/core/constants/app_constants.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/core/models/policy_schema_model.dart';
import 'package:sigad/core/models/vehicle_model.dart';
import 'package:sigad/core/repositories/policy_schemas_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/date_formatter.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_form/policy_basic_fields_section.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_form/policy_coverages_section.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_form/policy_schema_selector_section.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/dynamic_policy_form.dart';

class PolicyFormDialog extends StatefulWidget {
  final PolicyModel? initialPolicy;
  final CreatePolicyRequest? initialRequest;
  final List<ClientModel> clients;
  final PolicySchemasRepository? policySchemasRepository;
  final String? authToken;

  const PolicyFormDialog({
    super.key,
    this.initialPolicy,
    this.initialRequest,
    required this.clients,
    this.policySchemasRepository,
    this.authToken,
  });

  @override
  State<PolicyFormDialog> createState() => _PolicyFormDialogState();
}

class _PolicyFormDialogState extends State<PolicyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dynamicFormKey = GlobalKey<DynamicPolicyFormState>();
  late final PolicySchemasRepository _schemasRepo;

  late final TextEditingController _numCtrl, _brandCtrl, _modelCtrl, _yearCtrl, _plateCtrl, _valCtrl, _primaCtrl, _startCtrl, _endCtrl, _kmCtrl;
  late String _selectedClientDoc, _status;
  final List<String> _selectedCoverages = [];

  List<PolicySchemaListItemModel> _availableSchemas = [];
  PolicySchemaModel? _selectedSchemaDetail;
  String? _selectedSchemaId;
  bool _isLoadingSchemas = false;

  final List<String> _allCoverages = const [
    'Pérdida Total por Accidente', 'Pérdida Total por Robo', 'Daños Parciales al Vehículo',
    'Responsabilidad Civil', 'Asistencia Mecánica 24/7', 'Auto Sustituto (hasta 15 días)',
  ];

  @override
  void initState() {
    super.initState();
    _schemasRepo = widget.policySchemasRepository ?? PolicySchemasRepository();

    final p = widget.initialPolicy;
    final req = widget.initialRequest;
    final number = p?.number ?? req?.number ?? '';
    final brand = p?.vehicle?.brand ?? req?.vehicle?.brand ?? '';
    final model = p?.vehicle?.model ?? req?.vehicle?.model ?? '';
    final year = p?.vehicle?.year.toString() ?? req?.vehicle?.year.toString() ?? '';
    final plate = p?.vehicle?.plate ?? req?.vehicle?.plate ?? '';
    final val = (p != null && p.insuredValue > 0)
        ? p.insuredValue.toStringAsFixed(2)
        : (req?.insuredValue != null && req!.insuredValue! > 0 ? req.insuredValue!.toStringAsFixed(2) : '');
    final prima = (p != null && p.monthlyPremium > 0)
        ? p.monthlyPremium.toStringAsFixed(2)
        : (req?.monthlyPremium != null && req!.monthlyPremium! > 0 ? req.monthlyPremium!.toStringAsFixed(2) : '');
    final km = (p != null && p.emissionMileage > 0)
        ? p.emissionMileage.toString()
        : (req?.emissionMileage != null && req!.emissionMileage! > 0 ? req.emissionMileage!.toString() : '');
    final startDt = p?.startDate ?? req?.startDate ?? DateTime.now();
    final endDt = p?.endDate ?? req?.endDate ?? DateTime.now().add(const Duration(days: AppConstants.defaultPolicyDurationDays));

    _numCtrl = TextEditingController(text: number);
    _brandCtrl = TextEditingController(text: brand);
    _modelCtrl = TextEditingController(text: model);
    _yearCtrl = TextEditingController(text: year);
    _plateCtrl = TextEditingController(text: plate);
    _valCtrl = TextEditingController(text: val);
    _primaCtrl = TextEditingController(text: prima);
    _kmCtrl = TextEditingController(text: km);
    _startCtrl = TextEditingController(text: DateFormatter.toIsoDate(startDt));
    _endCtrl = TextEditingController(text: DateFormatter.toIsoDate(endDt));

    _status = p?.status ?? req?.status ?? 'activa';
    _selectedClientDoc = p?.clientId ?? req?.clientId ?? (widget.clients.isNotEmpty ? widget.clients.first.id : '');
    if (p != null) {
      _selectedCoverages.addAll(p.coverages.map((c) => c.nombre));
    } else if (req != null && req.coverages.isNotEmpty) {
      _selectedCoverages.addAll(req.coverages);
    } else {
      _selectedCoverages.add('Responsabilidad Civil');
    }

    _selectedSchemaId = p?.esquemaId ?? req?.esquemaId;
    _loadSchemas();
  }

  Future<void> _loadSchemas() async {
    setState(() => _isLoadingSchemas = true);
    try {
      final list = await _schemasRepo.getSchemas(token: widget.authToken);
      if (!mounted) return;
      setState(() {
        _availableSchemas = list;
        _isLoadingSchemas = false;
      });

      if (_selectedSchemaId != null) {
        await _fetchSchemaDetail(_selectedSchemaId!);
      } else {
        final activo = list.where((s) => s.esActivo).firstOrNull;
        if (activo != null) {
          _onSchemaSelected(activo.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSchemas = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar esquemas: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _fetchSchemaDetail(String schemaId) async {
    try {
      final detail = await _schemasRepo.getSchemaById(schemaId, token: widget.authToken);
      if (!mounted) return;
      setState(() {
        _selectedSchemaDetail = detail;
        _selectedSchemaId = schemaId;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar detalle del esquema: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _onSchemaSelected(String? schemaId) {
    if (schemaId == null) {
      setState(() {
        _selectedSchemaId = null;
        _selectedSchemaDetail = null;
      });
      return;
    }
    _fetchSchemaDetail(schemaId);
  }

  @override
  void dispose() {
    for (final c in [_numCtrl, _brandCtrl, _modelCtrl, _yearCtrl, _plateCtrl, _valCtrl, _primaCtrl, _startCtrl, _endCtrl, _kmCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSchemaDetail != null && !(_dynamicFormKey.currentState?.validate() ?? true)) {
      return;
    }

    final start = DateTime.tryParse(_startCtrl.text.trim());
    final end = DateTime.tryParse(_endCtrl.text.trim());

    if (start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato de fechas inválido (debe ser AAAA-MM-DD)')),
      );
      return;
    }

    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha de fin debe ser posterior al inicio')),
      );
      return;
    }

    final year = int.tryParse(_yearCtrl.text.trim());
    if (year == null || year < 1900 || year > DateTime.now().year + 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El año del vehículo no es válido')),
      );
      return;
    }

    final insuredVal = double.tryParse(_valCtrl.text.trim());
    if (insuredVal == null || insuredVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El valor asegurado debe ser mayor a 0')),
      );
      return;
    }

    final prima = double.tryParse(_primaCtrl.text.trim());
    if (prima == null || prima < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La prima mensual debe ser un valor positivo')),
      );
      return;
    }

    final km = int.tryParse(_kmCtrl.text.trim());
    if (km == null || km < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El kilometraje de emisión debe ser un entero >= 0')),
      );
      return;
    }

    final Map<String, dynamic>? camposAdicionales = _selectedSchemaDetail != null
        ? _dynamicFormKey.currentState?.getValues()
        : (widget.initialRequest?.camposAdicionales ?? widget.initialPolicy?.camposAdicionales);

    Navigator.of(context).pop(CreatePolicyRequest(
      number: _numCtrl.text.trim(),
      clientId: _selectedClientDoc,
      vehicleId: widget.initialPolicy?.vehicleId ?? widget.initialRequest?.vehicleId,
      vehicle: VehicleModel(
        plate: _plateCtrl.text.trim().toUpperCase(),
        brand: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: year,
      ),
      startDate: start,
      endDate: end,
      status: _status,
      insuredValue: insuredVal,
      monthlyPremium: prima,
      emissionMileage: km,
      coverages: List<String>.from(_selectedCoverages),
      deductibles: widget.initialPolicy?.deductibles ?? widget.initialRequest?.deductibles ?? const [],
      esquemaId: _selectedSchemaId,
      camposAdicionales: camposAdicionales,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialPolicy == null ? 'Nueva Póliza Vehicular' : 'Emisión de Póliza (Borrador)'),
      content: SizedBox(
        width: 650,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PolicyBasicFieldsSection(
                  numCtrl: _numCtrl,
                  status: _status,
                  onStatusChanged: (v) => setState(() => _status = v),
                  clients: widget.clients,
                  selectedClientDoc: _selectedClientDoc,
                  onClientChanged: (v) => setState(() => _selectedClientDoc = v),
                  brandCtrl: _brandCtrl,
                  modelCtrl: _modelCtrl,
                  yearCtrl: _yearCtrl,
                  plateCtrl: _plateCtrl,
                  valCtrl: _valCtrl,
                  primaCtrl: _primaCtrl,
                  kmCtrl: _kmCtrl,
                  startCtrl: _startCtrl,
                  endCtrl: _endCtrl,
                ),
                const SizedBox(height: 14),
                PolicySchemaSelectorSection(
                  dynamicFormKey: _dynamicFormKey,
                  isLoadingSchemas: _isLoadingSchemas,
                  selectedSchemaId: _selectedSchemaId,
                  availableSchemas: _availableSchemas,
                  selectedSchemaDetail: _selectedSchemaDetail,
                  onSchemaSelected: _onSchemaSelected,
                  initialDynamicValues: widget.initialRequest?.camposAdicionales ??
                      widget.initialPolicy?.camposAdicionales ??
                      const {},
                ),
                const SizedBox(height: 14),
                PolicyCoveragesSection(
                  allCoverages: _allCoverages,
                  selectedCoverages: _selectedCoverages,
                  onCoverageToggled: (cov, isSelected) {
                    setState(() {
                      if (isSelected) {
                        _selectedCoverages.add(cov);
                      } else {
                        _selectedCoverages.remove(cov);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
