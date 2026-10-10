import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/models/policy_schema_model.dart';
import 'package:sigad/core/testing/test_factories.dart';

void main() {
  group('PolicySchemaModel & DTOs Unit Tests', () {
    test('PolicySchemaFieldModel serializa y deserializa con tipos estrictos', () {
      final field = TestFactories.createPolicySchemaField(
        nombre: 'dispositivo_rastreo',
        tipo: 'booleano',
        esObligatorio: true,
        orden: 1,
        formatoFecha: null,
      );
      final json = field.toJson();

      final deserialized = PolicySchemaFieldModel.fromJson(json);

      expect(deserialized.nombre, equals('dispositivo_rastreo'));
      expect(deserialized.tipo, equals('booleano'));
      expect(deserialized.esObligatorio, isTrue);
      expect(deserialized.orden, equals(1));
      expect(deserialized.formatoFecha, isNull);
    });

    test('PolicySchemaFieldModel serializa formatoFecha si existe', () {
      final field = TestFactories.createPolicySchemaField(
        nombre: 'fecha_inspeccion',
        tipo: 'fecha',
        esObligatorio: false,
        orden: 2,
        formatoFecha: 'YYYY-MM-DD',
      );
      final json = field.toJson();

      expect(json['formato_fecha'], equals('YYYY-MM-DD'));
      final deserialized = PolicySchemaFieldModel.fromJson(json);
      expect(deserialized.formatoFecha, equals('YYYY-MM-DD'));
    });

    test('PolicySchemaListItemModel parsea correctamente contrato OpenAPI', () {
      final item = TestFactories.createPolicySchemaListItem(
        id: 'sch-pol-1',
        codigo: 'VEHICULAR_ESTANDAR',
        nombre: 'Póliza Livianos Estándar',
        version: 1,
        esActivo: true,
        createdAt: DateTime.parse('2026-03-01T12:00:00Z'),
      );
      final json = item.toJson();

      final model = PolicySchemaListItemModel.fromJson(json);

      expect(model.id, equals('sch-pol-1'));
      expect(model.codigo, equals('VEHICULAR_ESTANDAR'));
      expect(model.nombre, equals('Póliza Livianos Estándar'));
      expect(model.version, equals(1));
      expect(model.esActivo, isTrue);
    });

    test('PolicySchemaModel deserializa campos anidados estrictamente', () {
      final schema = TestFactories.createPolicySchema(
        id: 'sch-pol-detail-1',
        codigo: 'VEHICULAR_PESADOS',
        nombre: 'Póliza Pesados y Carga',
        descripcion: 'Esquema para camiones y buses',
        version: 2,
        esActivo: false,
        campos: [
          TestFactories.createPolicySchemaField(nombre: 'capacidad_tonelaje', tipo: 'decimal', esObligatorio: true),
          TestFactories.createPolicySchemaField(nombre: 'numero_ejes', tipo: 'numero', esObligatorio: true),
        ],
      );
      final json = schema.toJson();

      final model = PolicySchemaModel.fromJson(json);

      expect(model.id, equals('sch-pol-detail-1'));
      expect(model.codigo, equals('VEHICULAR_PESADOS'));
      expect(model.version, equals(2));
      expect(model.esActivo, isFalse);
      expect(model.campos, hasLength(2));
      expect(model.campos.first.nombre, equals('capacidad_tonelaje'));
      expect(model.campos.first.tipo, equals('decimal'));
      expect(model.campos.last.nombre, equals('numero_ejes'));
      expect(model.campos.last.tipo, equals('numero'));
    });

    test('CreatePolicySchemaRequest serializa a JSON de creación', () {
      final req = CreatePolicySchemaRequest(
        codigo: 'NUEVO_ESQUEMA',
        nombre: 'Nuevo Esquema de Prueba',
        descripcion: 'Una descripción',
        campos: [
          TestFactories.createPolicySchemaField(nombre: 'gps_instalado', tipo: 'booleano'),
        ],
      );
      final json = req.toJson();

      expect(json['codigo'], equals('NUEVO_ESQUEMA'));
      expect(json['nombre'], equals('Nuevo Esquema de Prueba'));
      expect(json['descripcion'], equals('Una descripción'));
      expect(json['campos'], hasLength(1));
    });

    test('PolicySchemaModel lanza TypeError si faltan campos obligatorios', () {
      final invalidJson = <String, dynamic>{
        'id': 'sch-err-1',
        'version': 1,
        'es_activo': true,
        'created_at': '2026-01-01T00:00:00Z',
      };

      expect(() => PolicySchemaModel.fromJson(invalidJson), throwsA(isA<TypeError>()));
    });
  });
}
