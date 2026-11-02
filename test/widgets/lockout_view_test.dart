import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sigad/features/auth/presentation/bloc/auth_event.dart';
import 'package:sigad/features/auth/presentation/widgets/lockout_view.dart';

class MockAuthBloc extends AuthBloc {
  final List<AuthEvent> dispatchedEvents = [];

  MockAuthBloc() : super();

  @override
  void add(AuthEvent event) {
    dispatchedEvents.add(event);
    super.add(event);
  }
}

void main() {
  group('LockoutView Anti-Bypass Security Tests', () {
    testWidgets('Deshabilita boton de reintento durante el periodo activo de bloqueo', (tester) async {
      final mockBloc = MockAuthBloc();
      final futureUnlock = DateTime.now().add(const Duration(minutes: 5));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockBloc,
            child: Scaffold(
              body: LockoutView(unlockTime: futureUnlock),
            ),
          ),
        ),
      );

      expect(find.text('Acceso Bloqueado'), findsOneWidget);
      expect(find.text('Bloqueado temporalmente'), findsOneWidget);

      final buttonFinder = find.byType(OutlinedButton);
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<OutlinedButton>(buttonFinder);
      expect(button.onPressed, isNull, reason: 'El botón debe estar deshabilitado mientras dure el bloqueo');

      await tester.tap(buttonFinder);
      await tester.pump();

      expect(mockBloc.dispatchedEvents, isEmpty, reason: 'No se debe emitir ResetLockout() prematuramente');
    });

    testWidgets('Habilita boton cuando el tiempo de bloqueo ha expirado', (tester) async {
      final mockBloc = MockAuthBloc();
      final pastUnlock = DateTime.now().subtract(const Duration(seconds: 1));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: mockBloc,
            child: Scaffold(
              body: LockoutView(unlockTime: pastUnlock),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(OutlinedButton);
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<OutlinedButton>(buttonFinder);
      expect(button.onPressed, isNotNull, reason: 'El botón debe estar habilitado al expirar el tiempo');

      await tester.tap(buttonFinder);
      await tester.pump();

      expect(mockBloc.dispatchedEvents.any((e) => e is ResetLockout), isTrue);
    });
  });
}
