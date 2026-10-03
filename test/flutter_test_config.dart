import 'dart:async';
import 'package:sigad/core/config/api_config.dart';
import 'helpers/test_fixtures.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ApiConfig.setBaseUrlForTesting(TestFixtures.testBaseUrl);
  await testMain();
}
