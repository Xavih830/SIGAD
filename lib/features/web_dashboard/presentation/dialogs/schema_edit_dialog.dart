import 'package:flutter/material.dart';
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
  String tipo;
  bool esObligatorio;

  _EditableFieldItem({
    required String nombre,
    required String regex,
    this.tipo = 'texto',
    this.esObligatorio = false,
  })  : nombreController = TextEditingController(text: nombre),
        regexController = TextEditingController(text: regex);

  void dispose() {
    nombreController.dispose();
    regexController.dispose();
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
      _fieldItems.add(
        _EditableFieldItem(
          nombre: campo.nombre,
          regex: campo.regex,
          tipo: campo.tipo,
          esObligatorio: campo.esObligatorio,
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
      _fieldItems.add(
        _EditableFieldItem(
          nombre: '',
          regex: '',
          tipo: 'texto',
          esObligatorio: false,
        ),
      );
      _validationError = null;
    });
  }

  void _eliminarCampo(int index) {
    if (_fieldItems.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El esquema debe contener al menos un campo/regla.'),
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
        setState(() => _validationError = 'El campo #${i + 1} no tiene nombre.');
        return;
      }

      if (regexCampo.isEmpty) {
        setState(() => _validationError = 'El campo "$nombreCampo" requiere una expresión regular.');
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
        width: 800,
        height: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
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

            // Banner explicativo de auditoría
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los documentos procesados anteriormente conservan intacto su esquema histórico y datos auditados. '
                      'Los cambios guardados generarán una nueva versión para extracciones futuras.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metadatos básicos del esquema
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
                      labelText: 'Descripción (Opcional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Título de sección de campos y botón agregar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Campos y Reglas de Extracción (${_fieldItems.length}):',
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

            // Error de validación si existe
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

            // Lista desplazable de campos
            Expanded(
              child: ListView.separated(
                itemCount: _fieldItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _fieldItems[index];
                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppTheme.borderLight),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Nombre de campo
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: item.nombreController,
                              decoration: InputDecoration(
                                labelText: 'Campo #${index + 1}',
                                hintText: 'ej. numero_poliza',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Expresión regular
                          Expanded(
                            flex: 5,
                            child: TextField(
                              controller: item.regexController,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Regex de Extracción',
                                hintText: r'(?:POLIZA):\s*([A-Z0-9]+)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Tipo de dato
                          SizedBox(
                            width: 125,
                            child: DropdownButtonFormField<String>(
                              value: item.tipo,
                              isDense: true,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Tipo',
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'texto', child: Text('Texto', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'numero', child: Text('Número', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'decimal', child: Text('Decimal', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'fecha', child: Text('Fecha', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => item.tipo = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Switch obligatorio
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Req.', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                              Checkbox(
                                value: item.esObligatorio,
                                visualDensity: VisualDensity.compact,
                                onChanged: (val) {
                                  setState(() => item.esObligatorio = val ?? false);
                                },
                              ),
                            ],
                          ),

                          // Botón borrar campo
                          IconButton(
                            onPressed: _isSaving ? null : () => _eliminarCampo(index),
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            tooltip: 'Eliminar este campo',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Pie del diálogo con acciones
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _activarInmediatamente,
                    onChanged: (val) {
                      setState(() => _activarInmediatamente = val ?? true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Activar automáticamente esta versión tras guardar',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  onPressed: _isSaving ? null : _guardarNuevaVersion,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, color: Colors.white, size: 16),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar Versión $proximaVersion',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
