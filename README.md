# Very Good Test Runner

[![Very Good Ventures][logo_black]][very_good_ventures_link_light]
[![Very Good Ventures][logo_white]][very_good_ventures_link_dark]

Developed with 💙 by [Very Good Ventures][very_good_ventures_link] 🦄

[![ci][ci_badge]][ci_link]
[![coverage][coverage_badge]][ci_link]
[![pub package][pub_badge]][pub_link]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

This package is a test runner for Flutter and Dart created by Very Good Ventures. It is intended to be used when writing custom tooling that runs Flutter or Dart tests and exposes a stream of `TestEvent` instances. For more information about the various `TestEvent` types, refer to the [JSON Reporter Test Protocol][json_reporter_test_protocol_link].

## Usage

```dart
import 'package:very_good_test_runner/very_good_test_runner.dart';

void main() {
  const arguments = ['--coverage'];
  const workingDirectory = 'path/to/project';

  // Run `dart test` process.
  dartTest(
    arguments: arguments,
    workingDirectory: workingDirectory,
  ).listen((TestEvent event) {
    // React to `TestEvent` instances.
    print(event);
  });

  // Run `flutter test` process.
  flutterTest(
    arguments: arguments,
    workingDirectory: workingDirectory,
  ).listen((TestEvent event) {
    // React to `TestEvent` instances.
    print(event);
  });
}
```

[ci_badge]: https://github.com/VeryGoodOpenSource/very_good_test_runner/workflows/very_good_test_runner/badge.svg
[ci_link]: https://github.com/VeryGoodOpenSource/very_good_test_runner/actions
[coverage_badge]: https://raw.githubusercontent.com/VeryGoodOpenSource/very_good_test_runner/main/coverage_badge.svg
[json_reporter_test_protocol_link]: https://github.com/dart-lang/test/blob/master/pkgs/test/doc/json_reporter.md
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[logo_black]: https://raw.githubusercontent.com/VGVentures/very_good_brand/main/styles/README/vgv_logo_black.png#gh-light-mode-only
[logo_white]: https://raw.githubusercontent.com/VGVentures/very_good_brand/main/styles/README/vgv_logo_white.png#gh-dark-mode-only
[pub_badge]: https://img.shields.io/pub/v/very_good_test_runner.svg
[pub_link]: https://pub.dartlang.org/packages/very_good_test_runner
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[very_good_ventures_link]: https://verygood.ventures/?utm_source=github
[very_good_ventures_link_dark]: https://verygood.ventures/?utm_source=github#gh-dark-mode-only
[very_good_ventures_link_light]: https://verygood.ventures/?utm_source=github#gh-light-mode-only
