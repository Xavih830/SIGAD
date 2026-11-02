import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/models/client_model.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/client_form_dialog.dart';
import 'package:sigad/shared/widgets/sigad_text_field.dart';

void main() {
  group('ClientFormDialog Widget Tests', () {
    testWidgets('Modo creación: renderiza campos vacíos y título Nuevo Cliente', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClientFormDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nuevo Cliente'), findsOneWidget);
      expect(find.text('Identificación (Cédula o RUC)'), findsOneWidget);
      expect(find.text('Nombre Completo'), findsOneWidget);
      expect(find.text('Correo Electrónico'), findsOneWidget);
      expect(find.text('Teléfono Móvil (10 dígitos)'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Guardar'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancelar'), findsOneWidget);
    });

    testWidgets('Modo creación: valida campos requeridos e identificación inválida', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClientFormDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Submit vacío
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('La identificación es requerida'), findsOneWidget);
      expect(find.text('El nombre es requerido'), findsOneWidget);
      expect(find.text('El correo es requerido'), findsOneWidget);
      expect(find.text('El teléfono es requerido'), findsOneWidget);

      // Ingresar identificación inválida
      await tester.enterText(find.byType(TextFormField).at(0), '12345');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Identificación no válida (Cédula o RUC)'), findsOneWidget);
    });

    testWidgets('Modo creación: submit con datos válidos retorna CreateClientRequest', (tester) async {
      dynamic poppedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  poppedResult = await showDialog(
                    context: ctx,
                    builder: (_) => const ClientFormDialog(),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // RUC persona natural válido: 0926687856001
      await tester.enterText(find.byType(TextFormField).at(0), '0926687856001');
      await tester.enterText(find.byType(TextFormField).at(1), 'Juan Pérez');
      await tester.enterText(find.byType(TextFormField).at(2), 'juan@test.com');
      await tester.enterText(find.byType(TextFormField).at(3), '0991234567');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(poppedResult, isA<CreateClientRequest>());
      final req = poppedResult as CreateClientRequest;
      expect(req.identificacion, equals('0926687856001'));
      expect(req.nombres, equals('Juan Pérez'));
      expect(req.email, equals('juan@test.com'));
      expect(req.telefono, equals('0991234567'));
    });

    testWidgets('Modo edición: precarga datos, identificación no editable y submit emite UpdateClientRequest', (tester) async {
      const initialClient = ClientModel(
        id: 'cli-123',
        identificacion: '1790016919001',
        nombres: 'Corporación Antigua S.A.',
        email: 'antigua@test.com',
        telefono: '022345678',
      );

      dynamic poppedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  poppedResult = await showDialog(
                    context: ctx,
                    builder: (_) => const ClientFormDialog(initialClient: initialClient),
                  );
                },
                child: const Text('Editar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Cliente'), findsOneWidget);
      expect(find.text('1790016919001'), findsOneWidget);
      expect(find.text('Corporación Antigua S.A.'), findsOneWidget);

      // Verificar que el campo identificación es de solo lectura (readOnly)
      final idField = tester.widget<SigadTextField>(find.byType(SigadTextField).at(0));
      expect(idField.readOnly, isTrue);

      // Modificar nombre y teléfono
      await tester.enterText(find.byType(TextFormField).at(1), 'Corporación Nueva S.A.');
      await tester.enterText(find.byType(TextFormField).at(3), '0998887777');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(poppedResult, isA<UpdateClientRequest>());
      final req = poppedResult as UpdateClientRequest;
      expect(req.nombres, equals('Corporación Nueva S.A.'));
      expect(req.email, equals('antigua@test.com'));
      expect(req.telefono, equals('0998887777'));
    });

    testWidgets('Presionar Cancelar cierra el diálogo sin emitir datos', (tester) async {
      dynamic poppedResult = 'no_cerrado';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  poppedResult = await showDialog(
                    context: ctx,
                    builder: (_) => const ClientFormDialog(),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(poppedResult, isNull);
    });
  });
}
