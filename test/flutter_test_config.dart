import 'dart:async';
import 'package:sigad/core/config/api_config.dart';
import 'package:sigad/core/services/session_vault.dart';
import 'helpers/test_fixtures.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ApiConfig.setBaseUrlForTesting(TestFixtures.testBaseUrl);
  SessionVault.enableTestMode();
  await testMain();
}
