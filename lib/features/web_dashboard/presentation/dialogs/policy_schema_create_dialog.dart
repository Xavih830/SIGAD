import 'package:flutter/material.dart';
import 'package:sigad/core/models/policy_schema_model.dart';
import 'package:sigad/core/repositories/policy_schemas_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';

class PolicySchemaCreateDialog extends StatefulWidget {
  final PolicySchemasRepository repository;
  final String? authToken;
  final PolicySchemaModel? initialSchema;

  const PolicySchemaCreateDialog({
    super.key,
    required this.repository,
    this.authToken,
    this.initialSchema,
  });

  @override
  State<PolicySchemaCreateDialog> createState() => _PolicySchemaCreateDialogState();
}

class _FieldItem {
  final TextEditingController nameCtrl;
  String tipo;
  bool esObligatorio;
  String? formatoFecha;

  _FieldItem({
    required String name,
    this.tipo = 'texto',
    this.esObligatorio = false,
    this.formatoFecha,
  }) : nameCtrl = TextEditingController(text: name);

  void dispose() {
    nameCtrl.dispose();
  }
}

class _PolicySchemaCreateDialogState extends State<PolicySchemaCreateDialog> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  final List<_FieldItem> _fields = [];
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final init = widget.initialSchema;
    _codeCtrl = TextEditingController(text: init?.codigo ?? '');
    _nameCtrl = TextEditingController(text: init?.nombre ?? '');
    _descCtrl = TextEditingController(text: init?.descripcion ?? '');

    if (init != null && init.campos.isNotEmpty) {
      for (final c in init.campos) {
        _fields.add(_FieldItem(
          name: c.nombre,
          tipo: c.tipo,
          esObligatorio: c.esObligatorio,
          formatoFecha: c.formatoFecha,
        ));
      }
    } else {
      _cargarPresetVehicular('VEHICULO_PESADO');
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _cargarPresetVehicular(String tipoPreset) {
    for (final f in _fields) {
      f.dispose();
    }
    _fields.clear();

    switch (tipoPreset) {
      case 'VEHICULO_PESADO':
        _codeCtrl.text = 'VEHICULOS_PESADOS';
        _nameCtrl.text = 'Póliza de Transporte Pesado y Carga';
        _descCtrl.text = 'Requisitos específicos para camiones, tráileres y transporte interprovincial.';
        _fields.addAll([
          _FieldItem(name: 'tonelaje_maximo', tipo: 'decimal', esObligatorio: true),
          _FieldItem(name: 'numero_ejes', tipo: 'numero', esObligatorio: true),
          _FieldItem(name: 'dispositivo_gps', tipo: 'booleano', esObligatorio: true),
          _FieldItem(name: 'tipo_carga', tipo: 'texto', esObligatorio: false),
          _FieldItem(name: 'fecha_inspeccion_mecanica', tipo: 'fecha', formatoFecha: 'YYYY-MM-DD', esObligatorio: false),
        ]);
        break;
      case 'VEHICULO_LIVIANO':
        _codeCtrl.text = 'VEHICULOS_LIVIANOS';
        _nameCtrl.text = 'Póliza para Automóviles y SUVs';
        _descCtrl.text = 'Cobertura para vehículos particulares y familiares.';
        _fields.addAll([
          _FieldItem(name: 'cilindrada_cc', tipo: 'numero', esObligatorio: false),
          _FieldItem(name: 'capacidad_pasajeros', tipo: 'numero', esObligatorio: true),
          _FieldItem(name: 'alarma_satelital', tipo: 'booleano', esObligatorio: false),
        ]);
        break;
      case 'VEHICULO_MOTO':
        _codeCtrl.text = 'MOTOCICLETAS';
        _nameCtrl.text = 'Póliza de Motos y Scooters';
        _descCtrl.text = 'Condiciones contractuales para vehículos de dos ruedas.';
        _fields.addAll([
          _FieldItem(name: 'cilindrada_cc', tipo: 'numero', esObligatorio: true),
          _FieldItem(name: 'tipo_uso', tipo: 'texto', esObligatorio: true),
          _FieldItem(name: 'casco_homologado', tipo: 'booleano', esObligatorio: true),
        ]);
        break;
      default:
        _fields.add(_FieldItem(name: 'campo_personalizado', tipo: 'texto'));
    }
    setState(() {});
  }

  void _addField() {
    setState(() {
      _fields.add(_FieldItem(name: ''));
    });
  }

  void _removeField(int index) {
    if (_fields.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El esquema debe tener al menos un campo definido.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }
    setState(() {
      final removed = _fields.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _guardar() async {
    final codigo = _codeCtrl.text.trim().toUpperCase();
    final nombre = _nameCtrl.text.trim();

    if (codigo.isEmpty || !RegExp(r'^[A-Z0-9_]+$').hasMatch(codigo)) {
      setState(() => _error = 'El código debe contener solo MAYÚSCULAS y guiones bajos (ej. VEHICULOS_PESADOS).');
      return;
    }

    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre descriptivo es obligatorio.');
      return;
    }

    if (_fields.isEmpty) {
      setState(() => _error = 'Debe definir al menos un campo personalizado.');
      return;
    }

    final nombresVistos = <String>{};
    final campos = <PolicySchemaFieldModel>[];

    for (int i = 0; i < _fields.length; i++) {
      final item = _fields[i];
      final fieldName = item.nameCtrl.text.trim().toLowerCase().replaceAll(' ', '_');

      if (fieldName.isEmpty) {
        setState(() => _error = 'El campo #${i + 1} requiere un identificador.');
        return;
      }

      if (nombresVistos.contains(fieldName)) {
        setState(() => _error = 'Identificador duplicado: "$fieldName".');
        return;
      }
      nombresVistos.add(fieldName);

      if (item.tipo == 'fecha' && (item.formatoFecha == null || item.formatoFecha!.isEmpty)) {
        item.formatoFecha = 'YYYY-MM-DD';
      }

      campos.add(PolicySchemaFieldModel(
        nombre: fieldName,
        tipo: item.tipo,
        esObligatorio: item.esObligatorio,
        orden: i,
        formatoFecha: item.tipo == 'fecha' ? item.formatoFecha : null,
      ));
    }

    setState(() {
      _error = null;
      _isSaving = true;
    });

    try {
      final request = CreatePolicySchemaRequest(
        codigo: codigo,
        nombre: nombre,
        descripcion: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        campos: campos,
      );

      final nuevoEsquema = await widget.repository.createSchema(request, token: widget.authToken);
      if (!mounted) return;
      Navigator.of(context).pop(nuevoEsquema);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'Error al registrar esquema de póliza: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 800,
        height: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.directions_car_outlined, color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Text(
                      'Nuevo Esquema de Póliza Vehicular',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Plantillas rápidas: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ActionChip(
                  label: const Text('Pesados / Carga', style: TextStyle(fontSize: 11)),
                  onPressed: () => _cargarPresetVehicular('VEHICULO_PESADO'),
                ),
                ActionChip(
                  label: const Text('Livianos / Sedán', style: TextStyle(fontSize: 11)),
                  onPressed: () => _cargarPresetVehicular('VEHICULO_LIVIANO'),
                ),
                ActionChip(
                  label: const Text('Motos', style: TextStyle(fontSize: 11)),
                  onPressed: () => _cargarPresetVehicular('VEHICULO_MOTO'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código Canónico *',
                      hintText: 'VEHICULOS_PESADOS',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Esquema *',
                      hintText: 'Póliza de Transporte Pesado',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción / Cobertura Especial (Opcional)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Campos Específicos del Vehículo (${_fields.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _addField,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar Campo'),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade900, fontSize: 12)),
              ),
              const SizedBox(height: 6),
            ],

            Expanded(
              child: ListView.separated(
                itemCount: _fields.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final f = _fields[index];
                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: AppTheme.borderLight),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: f.nameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Identificador #${index + 1}',
                                hintText: 'ej. tonelaje_maximo',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          SizedBox(
                            width: 140,
                            child: DropdownButtonFormField<String>(
                              initialValue: f.tipo,
                              isDense: true,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Tipo',
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'texto', child: Text('Texto')),
                                DropdownMenuItem(value: 'numero', child: Text('Número')),
                                DropdownMenuItem(value: 'decimal', child: Text('Decimal')),
                                DropdownMenuItem(value: 'fecha', child: Text('Fecha')),
                                DropdownMenuItem(value: 'booleano', child: Text('Booleano / Sí-No')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    f.tipo = val;
                                    if (val == 'fecha' && f.formatoFecha == null) {
                                      f.formatoFecha = 'YYYY-MM-DD';
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),

                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Oblig.', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                              Checkbox(
                                value: f.esObligatorio,
                                visualDensity: VisualDensity.compact,
                                onChanged: (v) => setState(() => f.esObligatorio = v ?? false),
                              ),
                            ],
                          ),

                          IconButton(
                            onPressed: _isSaving ? null : () => _removeField(index),
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            tooltip: 'Eliminar campo',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _guardar,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 16),
                  label: Text(_isSaving ? 'Guardando...' : 'Crear Esquema de Póliza'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

