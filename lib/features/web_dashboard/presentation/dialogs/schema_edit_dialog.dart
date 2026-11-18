import 'package:flutter/material.dart';
import 'package:sigad/core/models/extraction_rule_preset.dart';
import 'package:sigad/core/models/extraction_schema_model.dart';
import 'package:sigad/core/repositories/extraction_schemas_repository.dart';
import 'package:sigad/core/theme/app_theme.dart';

class SchemaEditDialog extends StatefulWidget {
  final ExtractionSchemaModel schema;
  final ExtractionSchemasRepository repository;
  final String? authToken;

  const SchemaEditDialog({
    super.key,
    required this.schema,
    required this.repository,
    this.authToken,
  });

  @override
  State<SchemaEditDialog> createState() => _SchemaEditDialogState();
}

class _EditableFieldItem {
  final TextEditingController nombreController;
  final TextEditingController regexController;
  final TextEditingController keywordController;
  String presetId;
  String tipo;
  bool esObligatorio;
  bool showAdvancedRegex;

  _EditableFieldItem({
    required String nombre,
    required String regex,
    this.presetId = 'personalizado_regex',
    this.tipo = 'texto',
    this.esObligatorio = false,
    this.showAdvancedRegex = false,
    String keyword = '',
  })  : nombreController = TextEditingController(text: nombre),
        regexController = TextEditingController(text: regex),
        keywordController = TextEditingController(text: keyword);

  void dispose() {
    nombreController.dispose();
    regexController.dispose();
    keywordController.dispose();
  }

  void updateFromPreset(ExtractionRulePreset preset) {
    presetId = preset.id;
    tipo = preset.tipoDato;
    if (preset.id != 'personalizado_regex') {
      showAdvancedRegex = false;
      if (preset.requiresKeyword) {
        regexController.text = preset.buildRegex(keywordController.text);
      } else {
        regexController.text = preset.regexPattern;
      }
    } else {
      showAdvancedRegex = true;
    }
  }
}

class _SchemaEditDialogState extends State<SchemaEditDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descCtrl;
  final List<_EditableFieldItem> _fieldItems = [];
  bool _activarInmediatamente = true;
  bool _isSaving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.schema.nombre);
    _descCtrl = TextEditingController(text: widget.schema.descripcion ?? '');

    for (final campo in widget.schema.campos) {
      final matchedPreset = ExtractionPresetCatalog.matchPresetFromRegex(campo.regex);
      final keyword = matchedPreset.id == 'texto_tras_etiqueta'
          ? ExtractionPresetCatalog.extractKeywordFromTextAfterLabel(campo.regex)
          : '';

      _fieldItems.add(
        _EditableFieldItem(
          nombre: campo.nombre,
          regex: campo.regex,
          presetId: matchedPreset.id,
          tipo: campo.tipo,
          esObligatorio: campo.esObligatorio,
          showAdvancedRegex: matchedPreset.id == 'personalizado_regex',
          keyword: keyword,
        ),
      );
    }

    if (_fieldItems.isEmpty) {
      _agregarCampo();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    for (final item in _fieldItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _agregarCampo() {
    setState(() {
      final defaultPreset = ExtractionPresetCatalog.plateEcuador;
      _fieldItems.add(
        _EditableFieldItem(
          nombre: '',
          regex: defaultPreset.regexPattern,
          presetId: defaultPreset.id,
          tipo: defaultPreset.tipoDato,
          esObligatorio: false,
          showAdvancedRegex: false,
        ),
      );
      _validationError = null;
    });
  }

  void _eliminarCampo(int index) {
    if (_fieldItems.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El esquema debe contener al menos un campo o regla.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }
    setState(() {
      final removed = _fieldItems.removeAt(index);
      removed.dispose();
      _validationError = null;
    });
  }

  Future<void> _guardarNuevaVersion() async {
    final nombreEsquema = _nombreCtrl.text.trim();
    if (nombreEsquema.isEmpty) {
      setState(() => _validationError = 'El nombre del esquema es obligatorio.');
      return;
    }

    if (_fieldItems.isEmpty) {
      setState(() => _validationError = 'Debe definir al menos un campo para el esquema.');
      return;
    }

    final nombresVistos = <String>{};
    final camposFinales = <ExtractionFieldModel>[];

    for (int i = 0; i < _fieldItems.length; i++) {
      final item = _fieldItems[i];
      final nombreCampo = item.nombreController.text.trim();
      final regexCampo = item.regexController.text.trim();

      if (nombreCampo.isEmpty) {
        setState(() => _validationError = 'El campo #${i + 1} requiere un nombre.');
        return;
      }

      if (regexCampo.isEmpty) {
        setState(() => _validationError = 'El campo "$nombreCampo" no tiene una regla o formato definido.');
        return;
      }

      if (nombresVistos.contains(nombreCampo)) {
        setState(() => _validationError = 'El nombre de campo "$nombreCampo" está duplicado.');
        return;
      }
      nombresVistos.add(nombreCampo);

      camposFinales.add(
        ExtractionFieldModel(
          nombre: nombreCampo,
          regex: regexCampo,
          tipo: item.tipo,
          esObligatorio: item.esObligatorio,
          orden: i,
        ),
      );
    }

    setState(() {
      _validationError = null;
      _isSaving = true;
    });

    try {
      final request = CreateSchemaRequest(
        codigo: widget.schema.codigo,
        nombre: nombreEsquema,
        descripcion: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        campos: camposFinales,
      );

      var nuevoEsquema = await widget.repository.createSchema(
        request,
        token: widget.authToken,
      );

      if (_activarInmediatamente) {
        nuevoEsquema = await widget.repository.activateSchema(
          nuevoEsquema.id,
          token: widget.authToken,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(nuevoEsquema);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _validationError = 'Error al guardar el esquema: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final proximaVersion = widget.schema.version + 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 860,
        height: 680,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Editar Esquema: ${widget.schema.nombre}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Código: ${widget.schema.codigo} • Creando Versión: $proximaVersion (Append-Only)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Diseño asistido de reglas: seleccione el tipo de información a capturar (placa, cédula, monto, fecha) '
                      'sin necesidad de programar expresiones técnicas.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Esquema *',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Aseguradora (Opcional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Campos de Extracción (${_fieldItems.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _agregarCampo,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar Campo'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_validationError != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _validationError!,
                  style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
            ],

            Expanded(
              child: ListView.separated(
                itemCount: _fieldItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _fieldItems[index];
                  final currentPreset = ExtractionPresetCatalog.findById(item.presetId);

                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppTheme.borderLight),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: item.nombreController,
                                  decoration: InputDecoration(
                                    labelText: 'Nombre Identificador #${index + 1}',
                                    hintText: 'ej. placa_vehiculo',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              Expanded(
                                flex: 4,
                                child: DropdownButtonFormField<String>(
                                  initialValue: item.presetId,
                                  isDense: true,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Regla / Tipo de Información',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: ExtractionPresetCatalog.allPresets.map((p) {
                                    return DropdownMenuItem(
                                      value: p.id,
                                      child: Text(
                                        p.label,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newPresetId) {
                                    if (newPresetId == null) return;
                                    final selectedPreset = ExtractionPresetCatalog.findById(newPresetId);
                                    setState(() {
                                      item.updateFromPreset(selectedPreset);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),

                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Oblig.', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                  Checkbox(
                                    value: item.esObligatorio,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (val) {
                                      setState(() => item.esObligatorio = val ?? false);
                                    },
                                  ),
                                ],
                              ),

                              IconButton(
                                onPressed: _isSaving ? null : () => _eliminarCampo(index),
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                tooltip: 'Eliminar este campo',
                              ),
                            ],
                          ),

                          if (currentPreset.requiresKeyword) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: item.keywordController,
                                    decoration: const InputDecoration(
                                      labelText: 'Palabra o Etiqueta Clave en el Documento',
                                      hintText: 'ej. Asegurado, Contratante, Motor',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.label_outline, size: 18),
                                    ),
                                    onChanged: (text) {
                                      setState(() {
                                        item.regexController.text = currentPreset.buildRegex(text);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${currentPreset.descripcion} (Ejemplo: ${currentPreset.ejemplo})',
                                  style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                                onPressed: () {
                                  setState(() {
                                    item.showAdvancedRegex = !item.showAdvancedRegex;
                                  });
                                },
                                child: Text(
                                  item.showAdvancedRegex ? 'Ocultar Regex' : 'Ajustar Regex',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),

                          if (item.showAdvancedRegex) ...[
                            const SizedBox(height: 6),
                            TextField(
                              controller: item.regexController,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Expresión Regular Subyacente (Solo Expertos)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _activarInmediatamente,
                    onChanged: (v) => setState(() => _activarInmediatamente = v ?? true),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Activar esta versión de inmediato para nuevas subidas de pólizas',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _guardarNuevaVersion,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save, size: 16),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar Versión $proximaVersion'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
