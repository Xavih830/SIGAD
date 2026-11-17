import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/models/policy_model.dart';
import 'package:sigad/features/web_dashboard/presentation/dialogs/policy_detail_dialog.dart';
import 'package:sigad/features/web_dashboard/presentation/widgets/policies_data_table.dart';

PolicyModel _samplePolicy({String status = 'activa'}) {
  return PolicyModel(
    id: 'pol-1',
    number: 'POL-2026-001',
    clientId: 'cli-1',
    vehicleId: 'veh-1',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2027, 1, 1),
    status: status,
    insuredValue: 25000.0,
    monthlyPremium: 120.0,
    emissionMileage: 15000,
    version: 2,
  );
}

void main() {
  testWidgets('PolicyDetailDialog muestra pestañas Datos, Coberturas, Documentos, Historial y cambios', (tester) async {
    final history = [
      PolicyHistoryEntry(
        id: 1,
        entidad: 'polizas',
        entidadId: 'pol-1',
        campo: 'prima_mensual',
        valorAnterior: '100.00',
        valorNuevo: '120.00',
        usuarioId: 'usr-admin',
        fecha: DateTime(2026, 11, 17),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PolicyDetailDialog(
            policy: _samplePolicy(),
            initialHistory: history,
            onEdit: () {},
          ),
        ),
      ),
    );

    expect(find.text('Datos'), findsOneWidget);
    expect(find.text('Coberturas'), findsOneWidget);
    expect(find.text('Documentos'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();

    expect(find.text('Campo: prima_mensual'), findsOneWidget);
    expect(find.textContaining('100.00'), findsOneWidget);
    expect(find.textContaining('120.00'), findsOneWidget);
  });

  testWidgets('PoliciesDataTable muestra acción Desactivar en pólizas activas y dispara callback', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    PolicyModel? deactivated;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PoliciesDataTable(
            policies: [
              _samplePolicy(status: 'activa'),
              _samplePolicy(status: 'cancelada'),
            ],
            onViewDetail: (_) {},
            onDeactivate: (p) => deactivated = p,
          ),
        ),
      ),
    );

    expect(find.text('Desactivar'), findsOneWidget);
    await tester.tap(find.text('Desactivar'));
    await tester.pump();

    expect(deactivated, isNotNull);
    expect(deactivated!.id, 'pol-1');
  });
}
