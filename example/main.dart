// This is not production code.
// ignore_for_file: avoid_print

import 'package:very_good_test_runner/very_good_test_runner.dart';

void main() {
  // React to `TestEvent` instances.
  flutterTest().listen(print);
}
