import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/shared/widgets/sigad_data_table.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('SigadDataTable Widget Tests', () {
    testWidgets('Muestra mensaje de estado vacio cuando no hay filas', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          SigadDataTable<String>(
            emptyMessage: 'No hay elementos para mostrar.',
            columns: [
              SigadColumn(
                label: const Text('Columna'),
                cellBuilder: (item) => Text(item),
              ),
            ],
            rows: const [],
          ),
        ),
      );

      expect(find.text('No hay elementos para mostrar.'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
    });

    testWidgets('Muestra indicador de progreso cuando isLoading es true', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          SigadDataTable<String>(
            isLoading: true,
            columns: [
              SigadColumn(
                label: const Text('Columna'),
                cellBuilder: (item) => Text(item),
              ),
            ],
            rows: const ['Item 1'],
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
    });

    testWidgets('Renderiza filas de datos y cabeceras correctamente', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          SigadDataTable<String>(
            columns: [
              SigadColumn(
                label: const Text('Nombre'),
                cellBuilder: (item) => Text(item),
              ),
            ],
            rows: const ['Alpha', 'Beta'],
          ),
        ),
      );

      expect(find.text('Nombre'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('Barra de paginacion muestra rango e invoca onPageChanged en botones', (tester) async {
      int? requestedSkip;

      await tester.pumpWidget(
        buildTestableWidget(
          SigadDataTable<String>(
            total: 30,
            skip: 10,
            limit: 10,
            onPageChanged: (newSkip) {
              requestedSkip = newSkip;
            },
            columns: [
              SigadColumn(
                label: const Text('Elemento'),
                cellBuilder: (item) => Text(item),
              ),
            ],
            rows: List.generate(10, (i) => 'Item ${i + 11}'),
          ),
        ),
      );

      expect(find.text('Mostrando 11–20 de 30'), findsOneWidget);

      // Tap botón página anterior -> debe saltar a 0
      final prevBtn = find.byTooltip('Página anterior');
      expect(prevBtn, findsOneWidget);
      await tester.tap(prevBtn);
      await tester.pump();
      expect(requestedSkip, equals(0));

      // Tap botón página siguiente -> debe saltar a 20
      final nextBtn = find.byTooltip('Página siguiente');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pump();
      expect(requestedSkip, equals(20));
    });
  });
}
