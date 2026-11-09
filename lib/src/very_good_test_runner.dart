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

/// The default grace period to wait for the test process to shut down
/// gracefully after the first `SIGTERM` before escalating.
const _defaultGracePeriod = Duration(seconds: 2);

/// The time to wait for the test process to exit after each escalation signal
/// (a second `SIGTERM` and, as a last resort, `SIGKILL`).
///
/// Kept separate from the grace period so the worst case stays bounded at
/// roughly `grace + 2 * _reapTimeout`.
const _reapTimeout = Duration(seconds: 1);

/// Runs `dart test` and returns a stream of [TestEvent]
/// reported by the process.
///
/// ```dart
/// void main() {
///   // React to `TestEvent` instances.
///   dartTest().listen(print);
/// }
/// ```
///
/// When the returned subscription is cancelled while the process is still
/// running, the process is sent a `SIGTERM` and given [grace] to exit before
/// the cancellation escalates. See [_terminateProcess] for the full sequence.
Stream<TestEvent> dartTest({
  List<String>? arguments,
  String? workingDirectory,
  Map<String, String>? environment,
  bool runInShell = false,
  Duration grace = _defaultGracePeriod,
  StartProcess startProcess = Process.start,
}) {
  return _runTestProcess(
    () => startProcess(
      'dart',
      ['test', ...?arguments, '--reporter=json'],
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    ),
    grace: grace,
  );
}

/// Runs `flutter test` and returns a stream of [TestEvent]
/// reported by the process.
///
/// ```dart
/// void main() {
///   // React to `TestEvent` instances.
///   flutterTest().listen(print);
/// }
/// ```
///
/// When the returned subscription is cancelled while the process is still
/// running, the process is sent a `SIGTERM` and given [grace] to exit before
/// the cancellation escalates. See [_terminateProcess] for the full sequence.
Stream<TestEvent> flutterTest({
  List<String>? arguments,
  String? workingDirectory,
  Map<String, String>? environment,
  bool runInShell = false,
  Duration grace = _defaultGracePeriod,
  StartProcess startProcess = Process.start,
}) {
  return _runTestProcess(
    () => startProcess(
      'flutter',
      ['test', ...?arguments, '--reporter=json'],
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    ),
    grace: grace,
  );
}

Stream<TestEvent> _runTestProcess(
  Future<Process> Function() processRunner, {
  required Duration grace,
}) {
  final controller = StreamController<TestEvent>();
  late StreamSubscription<dynamic> testEventSubscription;
  late StreamSubscription<dynamic> errorSubscription;
  late Future<Process> processFuture;

  Future<void> onListen() async {
    final stopwatch = Stopwatch()..start();
    processFuture = processRunner();
    final process = await processFuture;
    final errors = process.stderr.map((e) => utf8.decode(e).trim());
    final testEvents = process.stdout.mapToTestEvents();
    errorSubscription = errors.listen(controller.addError);
    testEventSubscription = testEvents.listen(
      controller.add,
      onError: controller.addError,
    );

    final exitCode = await process.exitCode;
    // Drain remaining events before emitting the exit event.
    await Future.wait([
      errorSubscription.asFuture<void>(),
      testEventSubscription.asFuture<void>(),
    ]);
    stopwatch.stop();
    if (controller.isClosed) return;
    controller.add(
      ExitTestEvent(time: stopwatch.elapsedMilliseconds, exitCode: exitCode),
    );
    await controller.close();
  }

  Future<void> onCancel() async {
    // Ensure the process has exited before cancelling the pipe subscriptions,
    // so that cancellation completing means the process is actually gone.
    await _terminateProcess(await processFuture, grace: grace);
    await errorSubscription.cancel();
    await testEventSubscription.cancel();
  }

  controller
    ..onListen = onListen
    ..onCancel = onCancel;

  return controller.stream;
}

/// Terminates [process] and resolves once it has exited (or every escalation
/// has been exhausted), so the caller can rely on the process being gone.
///
/// The sequence, escalating only when the previous step does not exit in time:
///
/// 1. Send `SIGTERM` ([Process.kill]) to request a graceful shutdown and wait
///    up to [grace] for the process to exit. Well-behaved runs, including
///    `flutter test`, exit here.
/// 2. Send a second `SIGTERM` and wait up to [_reapTimeout]. `dart test` treats
///    the first `SIGTERM` as "finish the tests in progress", which hangs when a
///    test never completes; a second signal makes `test_core` clean up its
///    (potentially very large) temp directory and exit at once.
/// 3. As a last resort send `SIGKILL` and wait up to [_reapTimeout]. This is
///    avoided until now because it skips `dart test`'s temp directory cleanup.
///
/// The worst case is bounded at roughly `grace + 2 * _reapTimeout`.
Future<void> _terminateProcess(
  Process process, {
  required Duration grace,
}) async {
  // 1. Request a graceful shutdown.
  process.kill();
  if (await _exitedWithin(process, grace)) return;

  // 2. A second SIGTERM forces most runners to exit immediately.
  process.kill();
  if (await _exitedWithin(process, _reapTimeout)) return;

  // 3. SIGKILL as a backstop. Do not block forever.
  process.kill(ProcessSignal.sigkill);
  await _exitedWithin(process, _reapTimeout);
}

/// Waits up to [timeout] for [process] to exit, returning whether it did.
Future<bool> _exitedWithin(Process process, Duration timeout) async {
  try {
    await process.exitCode.timeout(timeout);
    return true;
  } on TimeoutException {
    return false;
  }
}

extension on Stream<List<int>> {
  Stream<TestEvent> mapToTestEvents() {
    return transform(utf8.decoder)
        .transform(const LineSplitter())
        .map((line) => line.trim())
        .map<Map<String, Object?>>(_tryDecode)
        .where((value) => value.isNotEmpty)
        .map(TestEvent.fromJson);
  }

  Map<String, Object?> _tryDecode(String value) {
    try {
      if (value.isEmpty) return const {};
      return json.decode(value) as Map<String, Object?>;
    } on FormatException {
      return const {};
    }
  }
}
