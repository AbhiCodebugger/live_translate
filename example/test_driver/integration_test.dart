// Runs the integration tests with `flutter drive` and writes what they
// report to build/integration_response_data.json, even when a frame's
// expectations fail, so a failed replay run still gives its timings.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  // As long as the replay test's own timeout.
  timeout: const Duration(minutes: 30),
  writeResponseOnFailure: true,
);
