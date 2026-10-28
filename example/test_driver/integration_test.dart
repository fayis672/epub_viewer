// Driver for running the integration tests with `flutter drive`, which
// supports --profile builds (used for the performance benchmark):
//
//   flutter drive --profile -d macos \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/epub_performance_test.dart
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
