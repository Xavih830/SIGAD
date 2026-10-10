import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_schema_model.dart';
import 'package:sigad/core/theme/app_theme.dart';
import 'package:sigad/core/utils/date_formatter.dart';

class DynamicPolicyForm extends StatefulWidget {
  final PolicySchemaModel schema;
  final Map<String, dynamic> initialValues;

  const DynamicPolicyForm({
    super.key,
    required this.schema,
    this.initialValues = const {},
  });

  @override
  State<DynamicPolicyForm> createState() => DynamicPolicyFormState();
}

class DynamicPolicyFormState extends State<DynamicPolicyForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _booleans = {};

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  @override
  void didUpdateWidget(covariant DynamicPolicyForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schema.id != widget.schema.id) {
      _disposeControllers();
      _initFields();
    }
  }

  void _initFields() {
    for (final campo in widget.schema.campos) {
      final initialVal = widget.initialValues[campo.nombre];
      if (campo.tipo == 'booleano') {
        if (initialVal is bool) {
          _booleans[campo.nombre] = initialVal;
        } else if (initialVal is String) {
          _booleans[campo.nombre] = initialVal.toLowerCase() == 'true' || initialVal == '1' || initialVal.toLowerCase() == 'si';
        } else {
          _booleans[campo.nombre] = false;
        }
      } else {
        final textVal = initialVal != null ? initialVal.toString() : '';
        _controllers[campo.nombre] = TextEditingController(text: textVal);
      }
    }
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _booleans.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  String _formatLabel(String name) {
    return name
        .split('_')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  bool validate() {
    return _formKey.currentState?.validate() ?? true;
  }

  Map<String, dynamic> getValues() {
    final values = <String, dynamic>{};
    for (final campo in widget.schema.campos) {
      if (campo.tipo == 'booleano') {
        values[campo.nombre] = _booleans[campo.nombre] ?? false;
      } else {
        final text = _controllers[campo.nombre]?.text.trim() ?? '';
        if (text.isEmpty) {
          continue;
        }
        if (campo.tipo == 'numero') {
          final intVal = int.tryParse(text);
          if (intVal != null) {
            values[campo.nombre] = intVal;
          }
        } else if (campo.tipo == 'decimal') {
          final doubleVal = double.tryParse(text);
          if (doubleVal != null) {
            values[campo.nombre] = doubleVal;
          }
        } else {
          values[campo.nombre] = text;
        }
      }
    }
    return values;
  }

  Future<void> _selectDate(BuildContext context, String fieldName) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final formatted = DateFormatter.toIsoDate(picked);
      setState(() {
        _controllers[fieldName]?.text = formatted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.schema.campos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Este esquema no define campos adicionales.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
      );
    }

    final camposOrdenados = List<PolicySchemaFieldModel>.from(widget.schema.campos)
      ..sort((a, b) => a.orden.compareTo(b.orden));

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Campos del Esquema: ${widget.schema.nombre} (v${widget.schema.version})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...camposOrdenados.map((campo) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildFieldWidget(campo),
              )),
        ],
      ),
    );
  }

  Widget _buildFieldWidget(PolicySchemaFieldModel campo) {
    final label = _formatLabel(campo.nombre);
    final isRequired = campo.esObligatorio;

    if (campo.tipo == 'booleano') {
      return Material(
        color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppTheme.borderLight),
        ),
        child: SwitchListTile(
          title: Text(label, style: const TextStyle(fontSize: 14)),
          subtitle: Text(isRequired ? 'Obligatorio' : 'Opcional', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          value: _booleans[campo.nombre] ?? false,
          onChanged: (val) {
            setState(() {
              _booleans[campo.nombre] = val;
            });
          },
        ),
      );
    }

    if (campo.tipo == 'fecha') {
      final ctrl = _controllers[campo.nombre];
      return TextFormField(
        controller: ctrl,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          hintText: campo.formatoFecha ?? 'AAAA-MM-DD',
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today, size: 18),
            onPressed: () => _selectDate(context, campo.nombre),
          ),
        ),
        onTap: () => _selectDate(context, campo.nombre),
        validator: (v) {
          if (isRequired && (v == null || v.trim().isEmpty)) {
            return '$label es obligatorio';
          }
          return null;
        },
      );
    }

    final ctrl = _controllers[campo.nombre];
    final isNumber = campo.tipo == 'numero';
    final isDecimal = campo.tipo == 'decimal';

    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber
          ? TextInputType.number
          : (isDecimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text),
      decoration: InputDecoration(
        labelText: label + (isRequired ? ' *' : ''),
        hintText: isRequired ? 'Obligatorio' : 'Opcional',
      ),
      validator: (v) {
        if (isRequired && (v == null || v.trim().isEmpty)) {
          return '$label es obligatorio';
        }
        if (v != null && v.trim().isNotEmpty) {
          if (isNumber && int.tryParse(v.trim()) == null) {
            return '$label debe ser un número entero válido';
          }
          if (isDecimal && double.tryParse(v.trim()) == null) {
            return '$label debe ser un número decimal válido';
          }
        }
        return null;
      },
    );
  }
}
