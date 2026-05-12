// Driver entrypoint for `flutter drive --driver=test_driver/integration_test.dart`.
// Required on Windows desktop, where `flutter test integration_test/...` cannot
// read the GUI binary's stdout to discover the VM service URL.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
