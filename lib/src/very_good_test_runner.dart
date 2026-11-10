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

/// The default time the test process is given to exit after the first
/// `SIGTERM` before cancellation escalates.
const _defaultGracePeriod = Duration(seconds: 2);

/// The time the test process is given to exit after each escalation signal
/// (a second `SIGTERM` and, as a last resort, `SIGKILL`).
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
/// {@template very_good_test_runner.cancellation}
/// Cancelling the subscription stops the test process, and the future
/// returned by `cancel()` completes once the process has exited:
///
/// 1. A `SIGTERM` is sent and the process gets [gracePeriod] (2 seconds by
///    default) to exit.
/// 2. If it is still running, a second `SIGTERM` is sent and it gets 1 more
///    second.
/// 3. If it is still running, `SIGKILL` is sent and it gets 1 more second.
///
/// So `cancel()` takes at most about [gracePeriod] plus 2 seconds.
///
/// The signals go to the process that was started. When [runInShell] is
/// `true` that is the shell, not the test runner, and `SIGKILL` does not reach
/// child processes such as `flutter_tester`, so those may outlive the
/// cancellation.
/// {@endtemplate}
Stream<TestEvent> dartTest({
  List<String>? arguments,
  String? workingDirectory,
  Map<String, String>? environment,
  bool runInShell = false,
  Duration gracePeriod = _defaultGracePeriod,
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
    gracePeriod: gracePeriod,
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
/// {@macro very_good_test_runner.cancellation}
Stream<TestEvent> flutterTest({
  List<String>? arguments,
  String? workingDirectory,
  Map<String, String>? environment,
  bool runInShell = false,
  Duration gracePeriod = _defaultGracePeriod,
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
    gracePeriod: gracePeriod,
  );
}

Stream<TestEvent> _runTestProcess(
  Future<Process> Function() processRunner, {
  required Duration gracePeriod,
}) {
  final controller = StreamController<TestEvent>();
  final cancelled = Completer<void>();
  var hasExited = false;
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
    hasExited = true;
    // Drain remaining events before emitting the exit event. If the
    // subscription is cancelled meanwhile, onCancel cancels the pipes, so their
    // futures would never complete; stop waiting instead.
    await Future.any([
      Future.wait([
        errorSubscription.asFuture<void>(),
        testEventSubscription.asFuture<void>(),
      ]),
      cancelled.future,
    ]);
    stopwatch.stop();
    if (cancelled.isCompleted || controller.isClosed) return;
    controller.add(
      ExitTestEvent(time: stopwatch.elapsedMilliseconds, exitCode: exitCode),
    );
    await controller.close();
  }

  Future<void> onCancel() async {
    if (!cancelled.isCompleted) cancelled.complete();
    final process = await processFuture;
    // Make sure the process is gone before cancelling the pipe subscriptions,
    // so that cancellation completing means the process has exited.
    if (!hasExited) {
      await _terminateProcess(process, gracePeriod: gracePeriod);
    }
    await errorSubscription.cancel();
    await testEventSubscription.cancel();
  }

  controller
    ..onListen = onListen
    ..onCancel = onCancel;

  return controller.stream;
}

/// Terminates [process] and completes once it has exited, or once every step
/// below has run out of time:
///
/// 1. Send `SIGTERM` and wait up to [gracePeriod]. Well-behaved runs,
///    including `flutter test`, exit here.
/// 2. Send a second `SIGTERM` and wait up to [_reapTimeout]. On the first
///    signal `dart test` stops listening for signals and closes its runner,
///    which can hang when a test never completes. The second signal then
///    reaches Dart's default handler, which ends the process at once. See
///    `_execute` in
///    https://github.com/dart-lang/test/blob/master/pkgs/test_core/lib/src/executable.dart
/// 3. As a last resort, send `SIGKILL` and wait up to [_reapTimeout].
Future<void> _terminateProcess(
  Process process, {
  required Duration gracePeriod,
}) async {
  process.kill();
  if (await _exitedWithin(process, gracePeriod)) return;

  process.kill();
  if (await _exitedWithin(process, _reapTimeout)) return;

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
