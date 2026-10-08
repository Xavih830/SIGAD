import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/models/extraction_schema_model.dart';
import '../helpers/test_factories.dart';

void main() {
  group('ExtractionSchemaModel & DTOs Unit Tests (Fail-Fast Radical)', () {
    test('ExtractionFieldModel serializa y deserializa con tipos estrictos', () {
      final field = TestFactories.createExtractionField(
        nombre: 'placa_vehiculo',
        regex: r'[A-Z]{3}-\d{4}',
        tipo: 'texto',
        grupoCaptura: 1,
        esObligatorio: true,
        orden: 1,
      );
      final json = field.toJson();

      final deserialized = ExtractionFieldModel.fromJson(json);

      expect(deserialized.nombre, equals('placa_vehiculo'));
      expect(deserialized.regex, equals(r'[A-Z]{3}-\d{4}'));
      expect(deserialized.tipo, equals('texto'));
      expect(deserialized.grupoCaptura, equals(1));
      expect(deserialized.esObligatorio, isTrue);
      expect(deserialized.orden, equals(1));
    });

    test('ExtractionSchemaListItemModel parsea correctamente contrato OpenAPI', () {
      final item = TestFactories.createExtractionSchemaListItem(
        id: 'sch-list-1',
        codigo: 'POLIZA_VEHICULAR',
        nombre: 'Póliza Automotriz',
        version: 2,
        esActivo: true,
        createdAt: DateTime.parse('2026-03-01T12:00:00Z'),
      );
      final json = item.toJson();

      final model = ExtractionSchemaListItemModel.fromJson(json);

      expect(model.id, equals('sch-list-1'));
      expect(model.codigo, equals('POLIZA_VEHICULAR'));
      expect(model.version, equals(2));
      expect(model.esActivo, isTrue);
    });

    test('ExtractionSchemaModel deserializa campos anidados estrictamente', () {
      final schema = TestFactories.createExtractionSchema(
        id: 'sch-detail-1',
        codigo: 'MATRICULA_ANT',
        nombre: 'Matrícula Vehicular ANT',
        descripcion: 'Extracción de datos de matrícula ecuatoriana',
        version: 3,
        esActivo: false,
        campos: [
          TestFactories.createExtractionField(nombre: 'chasis', regex: r'VIN:([A-Z0-9]+)'),
          TestFactories.createExtractionField(nombre: 'motor', regex: r'ENG:([A-Z0-9]+)'),
        ],
      );
      final json = schema.toJson();

      final model = ExtractionSchemaModel.fromJson(json);

      expect(model.id, equals('sch-detail-1'));
      expect(model.codigo, equals('MATRICULA_ANT'));
      expect(model.version, equals(3));
      expect(model.esActivo, isFalse);
      expect(model.campos, hasLength(2));
      expect(model.campos.first.nombre, equals('chasis'));
      expect(model.campos.last.nombre, equals('motor'));
    });

    test('TestSchemaResultModel deserializa resultado de prueba en memoria', () {
      final result = TestFactories.createTestSchemaResult(
        metodo: 'tesseract_200dpi',
        confianza: 88.5,
        camposExtraidos: {'placa': 'ABC-1234', 'anio': '2023'},
        textoCompleto: 'DOCUMENTO VEHICULAR PLACA ABC-1234 ANIO 2023',
      );
      final json = result.toJson();

      final model = TestSchemaResultModel.fromJson(json);

      expect(model.metodo, equals('tesseract_200dpi'));
      expect(model.confianza, equals(88.5));
      expect(model.camposExtraidos['placa'], equals('ABC-1234'));
      expect(model.textoCompleto, contains('DOCUMENTO VEHICULAR'));
    });

    test('Fail-Fast: ExtractionSchemaModel lanza TypeError si faltan campos obligatorios', () {
      final invalidJson = <String, dynamic>{
        'id': 'sch-err-1',
        // falta codigo y nombre
        'version': 1,
        'es_activo': true,
        'created_at': '2026-01-01T00:00:00Z',
      };

      expect(() => ExtractionSchemaModel.fromJson(invalidJson), throwsA(isA<TypeError>()));
    });
  });
}
