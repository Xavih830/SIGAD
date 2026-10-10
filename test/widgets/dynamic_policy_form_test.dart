import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/dynamic_policy_form.dart';
import 'package:sigad/core/testing/test_factories.dart';

void main() {
  group('DynamicPolicyForm Widget Tests', () {
    final schema = TestFactories.createPolicySchema(
      id: 'sch-test-1',
      codigo: 'VEHICULAR_COMPLETO',
      nombre: 'Póliza Completa',
      version: 1,
      campos: [
        TestFactories.createPolicySchemaField(
          nombre: 'numero_chasis',
          tipo: 'texto',
          esObligatorio: true,
          orden: 1,
        ),
        TestFactories.createPolicySchemaField(
          nombre: 'numero_pasajeros',
          tipo: 'numero',
          esObligatorio: false,
          orden: 2,
        ),
        TestFactories.createPolicySchemaField(
          nombre: 'tonelaje_maximo',
          tipo: 'decimal',
          esObligatorio: false,
          orden: 3,
        ),
        TestFactories.createPolicySchemaField(
          nombre: 'rastreo_satelital',
          tipo: 'booleano',
          esObligatorio: false,
          orden: 4,
        ),
        TestFactories.createPolicySchemaField(
          nombre: 'fecha_inspeccion',
          tipo: 'fecha',
          esObligatorio: false,
          orden: 5,
        ),
      ],
    );

    testWidgets('Renderiza todos los campos tipados y precarga valores iniciales', (tester) async {
      final formKey = GlobalKey<DynamicPolicyFormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicPolicyForm(
                key: formKey,
                schema: schema,
                initialValues: const {
                  'numero_chasis': '9BWZZZ377VT004251',
                  'numero_pasajeros': 5,
                  'tonelaje_maximo': 3.5,
                  'rastreo_satelital': true,
                  'fecha_inspeccion': '2026-05-10',
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Campos del Esquema: Póliza Completa (v1)'), findsOneWidget);
      expect(find.textContaining('Numero Chasis *'), findsOneWidget);
      expect(find.textContaining('Numero Pasajeros'), findsOneWidget);
      expect(find.textContaining('Tonelaje Maximo'), findsOneWidget);
      expect(find.textContaining('Rastreo Satelital'), findsOneWidget);
      expect(find.textContaining('Fecha Inspeccion'), findsOneWidget);

      expect(find.text('9BWZZZ377VT004251'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3.5'), findsOneWidget);
      expect(find.text('2026-05-10'), findsOneWidget);

      final state = formKey.currentState;
      expect(state, isNotNull);
      expect(state!.validate(), isTrue);

      final values = state.getValues();
      expect(values['numero_chasis'], equals('9BWZZZ377VT004251'));
      expect(values['numero_pasajeros'], equals(5));
      expect(values['tonelaje_maximo'], equals(3.5));
      expect(values['rastreo_satelital'], isTrue);
      expect(values['fecha_inspeccion'], equals('2026-05-10'));
    });

    testWidgets('Valida campos obligatorios y tipos inválidos', (tester) async {
      final formKey = GlobalKey<DynamicPolicyFormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicPolicyForm(
                key: formKey,
                schema: schema,
                initialValues: const {},
              ),
            ),
          ),
        ),
      );

      final state = formKey.currentState!;
      // El campo numero_chasis es obligatorio y está vacío -> validate() debe fallar
      expect(state.validate(), isFalse);
      await tester.pump();

      expect(find.text('Numero Chasis es obligatorio'), findsOneWidget);

      // Ingresar texto válido en numero_chasis pero texto inválido en numero_pasajeros
      await tester.enterText(find.widgetWithText(TextFormField, 'Numero Chasis *'), 'CHASIS-VALIDO-123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Numero Pasajeros'), 'cinco');
      await tester.pump();

      expect(state.validate(), isFalse);
      await tester.pump();
      expect(find.text('Numero Pasajeros debe ser un número entero válido'), findsOneWidget);

      // Corregir numero_pasajeros con un entero
      await tester.enterText(find.widgetWithText(TextFormField, 'Numero Pasajeros'), '4');
      await tester.pump();

      expect(state.validate(), isTrue);
      final values = state.getValues();
      expect(values['numero_chasis'], equals('CHASIS-VALIDO-123'));
      expect(values['numero_pasajeros'], equals(4));
    });
  });
}
