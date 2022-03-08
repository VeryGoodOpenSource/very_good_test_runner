import 'dart:async';
import 'dart:convert';

import 'package:universal_io/io.dart';
import 'package:very_good_test_runner/very_good_test_runner.dart';

/// Signature for `Process.start`.
typedef StartProcess = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment,
  bool runInShell,
  ProcessStartMode mode,
});

/// Runs `flutter test` and returns a stream of [TestEvent]
/// reported by the process.
Stream<TestEvent> flutterTest({
  List<String>? arguments,
  String? workingDirectory,
  Map<String, String>? environment,
  bool runInShell = false,
  StartProcess startProcess = Process.start,
}) {
  final controller = StreamController<TestEvent>();
  late StreamSubscription testEventSubscription;
  late StreamSubscription errorSubscription;
  late Future<Process> processFuture;

  Future<void> _onListen() async {
    processFuture = startProcess(
      'flutter',
      ['test', ...?arguments, '--reporter=json'],
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
    final process = await processFuture;
    final errors = process.stderr.map((e) => utf8.decode(e).trim());
    final testEvents = process.stdout.asTestEvents();
    errorSubscription = errors.listen(controller.addError);
    testEventSubscription = testEvents.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
  }

  Future<void> _onCancel() async {
    await controller.close();
    (await processFuture).kill();
    await errorSubscription.cancel();
    await testEventSubscription.cancel();
  }

  controller
    ..onListen = _onListen
    ..onCancel = _onCancel;

  return controller.stream;
}

extension on Stream<List<int>> {
  Stream<TestEvent> asTestEvents() {
    return map(utf8.decode)
        .expand<String>((msg) sync* {
          for (final value in msg.split('\n')) {
            final trimmedValue = value.trim();
            if (trimmedValue.isNotEmpty) yield trimmedValue;
          }
        })
        .expand<Object?>((j) {
          try {
            return [json.decode(j)];
          } on FormatException {
            return [];
          }
        })
        .cast<Map<Object?, Object?>>()
        .map((json) => TestEvent.fromJson(Map<String, dynamic>.from(json)));
  }
}
