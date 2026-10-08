import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigad/core/cache/in_memory_cache.dart';
import 'package:sigad/core/constants/api_endpoints.dart';
import 'package:sigad/core/constants/app_constants.dart';
import 'package:sigad/core/constants/domain_status.dart';
import 'package:sigad/core/models/user_model.dart';
import 'package:sigad/core/security/app_capability.dart';
import 'package:sigad/core/security/authorization_policy.dart';
import 'package:sigad/core/security/file_security_validator.dart';
import 'package:sigad/features/web_dashboard/domain/dashboard_tab_registry.dart';
import 'helpers/test_factories.dart';

void main() {
  group('1. Matriz de Autorización y Capacidades (CBAC)', () {
    final admin = TestFactories.createUser(role: UserRole.admin);
    final agente = TestFactories.createUser(role: UserRole.agente);
    final cliente = TestFactories.createUser(role: UserRole.cliente);

    test('Administrador posee todas las capacidades de gestión y reportes', () {
      expect(AuthorizationPolicy.canUser(admin, AppCapability.viewPolicies), isTrue);
      expect(AuthorizationPolicy.canUser(admin, AppCapability.createPolicy), isTrue);
      expect(AuthorizationPolicy.canUser(admin, AppCapability.viewClients), isTrue);
      expect(AuthorizationPolicy.canUser(admin, AppCapability.scanOcr), isTrue);
      expect(AuthorizationPolicy.canUser(admin, AppCapability.viewReports), isTrue);
      expect(AuthorizationPolicy.canUser(admin, AppCapability.viewAlerts), isTrue);
      expect(AuthorizationPolicy.canUser(admin, AppCapability.accessWebDashboard), isTrue);
      expect(AuthorizationPolicy.canUser(admin, AppCapability.accessMobileApp), isFalse);
    });

    test('Agente posee capacidades operativas pero no reportes globales', () {
      expect(AuthorizationPolicy.canUser(agente, AppCapability.viewPolicies), isTrue);
      expect(AuthorizationPolicy.canUser(agente, AppCapability.createPolicy), isTrue);
      expect(AuthorizationPolicy.canUser(agente, AppCapability.viewClients), isTrue);
      expect(AuthorizationPolicy.canUser(agente, AppCapability.scanOcr), isTrue);
      expect(AuthorizationPolicy.canUser(agente, AppCapability.viewReports), isFalse);
      expect(AuthorizationPolicy.canUser(agente, AppCapability.viewAlerts), isTrue);
      expect(AuthorizationPolicy.canUser(agente, AppCapability.accessWebDashboard), isTrue);
    });

    test('Cliente asegurado únicamente accede a sus pólizas y app móvil', () {
      expect(AuthorizationPolicy.canUser(cliente, AppCapability.viewPolicies), isTrue);
      expect(AuthorizationPolicy.canUser(cliente, AppCapability.accessMobileApp), isTrue);
      expect(AuthorizationPolicy.canUser(cliente, AppCapability.accessWebDashboard), isFalse);
      expect(AuthorizationPolicy.canUser(cliente, AppCapability.viewClients), isFalse);
      expect(AuthorizationPolicy.canUser(cliente, AppCapability.scanOcr), isFalse);
      expect(AuthorizationPolicy.canUser(cliente, AppCapability.viewReports), isFalse);
    });
  });

  group('2. Registro Canónico de Pestañas (DashboardTabRegistry)', () {
    test('Filtra pestañas según capacidades del usuario sin duplicación', () {
      final admin = TestFactories.createUser(role: UserRole.admin);
      final agente = TestFactories.createUser(role: UserRole.agente);

      final adminTabs = DashboardTabRegistry.getPermittedTabs(admin);
      final agentTabs = DashboardTabRegistry.getPermittedTabs(agente);

      // Admin debe tener las 6 pestañas (incluyendo esquemas OCR)
      expect(adminTabs.length, equals(6));
      expect(adminTabs.any((t) => t.id == 'reports'), isTrue);
      expect(adminTabs.any((t) => t.id == 'schemas'), isTrue);

      // Agente no debe tener acceso a reports ni schemas
      expect(agentTabs.length, equals(4));
      expect(agentTabs.any((t) => t.id == 'reports'), isFalse);
      expect(agentTabs.any((t) => t.id == 'schemas'), isFalse);
    });

    test('findTabById retorna la pestaña correcta o null si no existe', () {
      final tab = DashboardTabRegistry.findTabById('policies');
      expect(tab, isNotNull);
      expect(tab!.title, equals('Gestión de Pólizas Vehiculares'));

      final nonExistent = DashboardTabRegistry.findTabById('users_inexistente');
      expect(nonExistent, isNull);
    });
  });

  group('3. Caché en Memoria Genérico con TTL (InMemoryCache)', () {
    test('Almacena, recupera y expira según el TTL configurado', () async {
      final cache = InMemoryCache<String>(ttl: const Duration(milliseconds: 50));
      expect(cache.get(), isNull);
      expect(cache.isValid, isFalse);

      cache.set('valor_valido');
      expect(cache.get(), equals('valor_valido'));
      expect(cache.isValid, isTrue);

      // Esperar expiración
      await Future.delayed(const Duration(milliseconds: 60));
      expect(cache.get(), isNull);
      expect(cache.isValid, isFalse);
    });

    test('invalidate purga inmediatamente el dato almacenado', () {
      final cache = InMemoryCache<int>(ttl: const Duration(minutes: 5));
      cache.set(42);
      expect(cache.get(), equals(42));

      cache.invalidate();
      expect(cache.get(), isNull);
    });
  });

  group('4. Validador Pre-Vuelo de Archivos (FileSecurityValidator)', () {
    test('Acepta archivo PDF legítimo con firma binaria %PDF-', () {
      final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x35]);
      expect(
        () => FileSecurityValidator.validatePreFlight(bytes: pdfBytes, filename: 'poliza.pdf'),
        returnsNormally,
      );
    });

    test('Acepta archivo JPEG legítimo con firma binaria FFD8FF', () {
      final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      expect(
        () => FileSecurityValidator.validatePreFlight(bytes: jpegBytes, filename: 'foto.jpg'),
        returnsNormally,
      );
    });

    test('Acepta archivo PNG legítimo con firma binaria 89504E47', () {
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
      expect(
        () => FileSecurityValidator.validatePreFlight(bytes: pngBytes, filename: 'scan.png'),
        returnsNormally,
      );
    });

    test('Falla-Rápido si el archivo está vacío', () {
      expect(
        () => FileSecurityValidator.validatePreFlight(bytes: Uint8List(0), filename: 'vacio.pdf'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Falla-Rápido si el archivo excede los 15 MB de AppConstants', () {
      final bigBytes = Uint8List(AppConstants.maxDocumentSizeBytes + 1);
      expect(
        () => FileSecurityValidator.validatePreFlight(bytes: bigBytes, filename: 'pesado.pdf'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Falla-Rápido si la extensión no está permitida', () {
      final exeBytes = Uint8List.fromList([0x4D, 0x5A, 0x90, 0x00]);
      expect(
        () => FileSecurityValidator.validatePreFlight(bytes: exeBytes, filename: 'malware.exe'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Falla-Rápido si el archivo tiene extensión .pdf pero firma corrupta', () {
      final fakeBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04]);
      expect(
        () => FileSecurityValidator.validatePreFlight(bytes: fakeBytes, filename: 'falso.pdf'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('5. Estados de Dominio Tipados (DomainStatus Fail-Fast)', () {
    test('ExtractionStatus parsea estados válidos y falla ante desconocidos', () {
      expect(ExtractionStatus.fromValue('completado'), equals(ExtractionStatus.completado));
      expect(ExtractionStatus.fromValue('pendiente'), equals(ExtractionStatus.pendiente));
      expect(ExtractionStatus.fromValue('procesando'), equals(ExtractionStatus.procesando));
      expect(ExtractionStatus.fromValue('revision_requerida'), equals(ExtractionStatus.revisionRequerida));
      expect(ExtractionStatus.fromValue('fallido'), equals(ExtractionStatus.fallido));

      expect(() => ExtractionStatus.fromValue('desconocido_magico'), throwsA(isA<StateError>()));
    });

    test('PolicyStatus parsea estados canónicos y falla ante desconocidos', () {
      expect(PolicyStatus.fromValue('vigente'), equals(PolicyStatus.vigente));
      expect(PolicyStatus.fromValue('por_vencer'), equals(PolicyStatus.porVencer));
      expect(PolicyStatus.fromValue('vencida'), equals(PolicyStatus.vencida));
      expect(PolicyStatus.fromValue('anulada'), equals(PolicyStatus.anulada));

      expect(() => PolicyStatus.fromValue('estado_invalido'), throwsA(isA<StateError>()));
    });

    test('PaymentStatus parsea estados de cuota y falla ante desconocidos', () {
      expect(PaymentStatus.fromValue('pagado'), equals(PaymentStatus.pagado));
      expect(PaymentStatus.fromValue('pendiente'), equals(PaymentStatus.pendiente));
      expect(PaymentStatus.fromValue('atrasado'), equals(PaymentStatus.atrasado));
      expect(PaymentStatus.fromValue('parcial'), equals(PaymentStatus.parcial));

      expect(() => PaymentStatus.fromValue('invalido'), throwsA(isA<StateError>()));
    });
  });

  group('6. Rutas de Endpoints y Parámetros (ApiEndpoints)', () {
    test('Genera rutas de pólizas con skip y limit correctos', () {
      expect(ApiEndpoints.polizas(skip: 0, limit: 50), equals('/api/v1/polizas?skip=0&limit=50'));
      expect(ApiEndpoints.polizas(skip: 10, limit: 25), equals('/api/v1/polizas?skip=10&limit=25'));
      expect(ApiEndpoints.poliza('pol-123'), equals('/api/v1/polizas/pol-123'));
    });

    test('Genera rutas de documentos y pagos', () {
      expect(ApiEndpoints.documentoRevision('doc-99'), equals('/api/v1/documentos/doc-99/revision'));
      expect(ApiEndpoints.polizaRegistrarPago('pol-1', 'pay-2'), equals('/api/v1/polizas/pol-1/pagos/pay-2/registrar'));
    });
  });
}
