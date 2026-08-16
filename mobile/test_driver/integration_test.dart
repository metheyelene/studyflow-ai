import 'package:integration_test/integration_test_driver_extended.dart';

/// Standard driver: `flutter drive --driver=test_driver/integration_test.dart
/// --target=integration_test/` + a test name — persists the app's timeline
/// (frame build/raster stats) alongside the test's printed output.
Future<void> main() => integrationDriver();
