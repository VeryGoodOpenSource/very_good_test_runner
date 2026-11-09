import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';
import 'package:very_good_test_runner/src/very_good_test_runner.dart'
    show StartProcess;
import 'package:very_good_test_runner/very_good_test_runner.dart';

// Needed for test setup
abstract class TestProcess {
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = false,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  });
}

class MockTestProcess extends Mock implements TestProcess;

class MockProcess extends Mock implements Process;

/// A fake [Process] that records the signals it receives via [kill].
///
/// It exits once it has received [exitAfterSignals] signals, modelling a
/// process that survives that many signals before dying. When
/// [exitAfterSignals] is `null` it only exits when [terminate] is called.
class FakeProcess extends Fake implements Process {
  new({this.exitAfterSignals});

  /// The number of signals the process survives before exiting, or `null` to
  /// only exit when [terminate] is called.
  final int? exitAfterSignals;

  final _exitCodeCompleter = Completer<int>();

  /// Backs [stdout], so tests can check whether it is still listened to.
  final stdoutController = StreamController<List<int>>();

  /// Backs [stderr], so tests can check whether it is still listened to.
  final stderrController = StreamController<List<int>>();

  /// The signals passed to [kill], in order.
  final killSignals = <ProcessSignal>[];

  /// Whether the process has exited.
  bool get hasExited => _exitCodeCompleter.isCompleted;

  @override
  Stream<List<int>> get stdout => stdoutController.stream;

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  /// Simulates the process exiting with [code] and closing its output pipes.
  void terminate([int code = 0]) {
    if (hasExited) return;
    _exitCodeCompleter.complete(code);
    unawaited(stdoutController.close());
    unawaited(stderrController.close());
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killSignals.add(signal);
    if (exitAfterSignals != null && killSignals.length >= exitAfterSignals!) {
      terminate();
    }
    return true;
  }
}

/// Builds a [StartProcess] that resolves to [process] once [started]
/// completes.
///
/// When [started] is omitted the process is available immediately.
StartProcess _startProcessReturning(Process process, {Future<void>? started}) {
  return (
    executable,
    arguments, {
    workingDirectory,
    environment,
    includeParentEnvironment = false,
    runInShell = false,
    mode = ProcessStartMode.normal,
  }) async {
    if (started != null) await started;
    return process;
  };
}

/// The public entry points, so that cancellation is tested through both.
final _testRunners =
    <
      String,
      Stream<TestEvent> Function({
        Duration gracePeriod,
        StartProcess startProcess,
      })
    >{'dartTest': dartTest, 'flutterTest': flutterTest};
void main() {
  group('dartTest', () {
    late StreamController<List<int>> stdoutController;
    late StreamController<List<int>> stderrController;
    late Process process;
    late TestProcess testProcess;

    setUp(() {
      stdoutController = StreamController();
      stderrController = StreamController();
      process = MockProcess();
      testProcess = MockTestProcess();
      when(
        () => testProcess.start(
          any(),
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
          includeParentEnvironment: any(named: 'includeParentEnvironment'),
          runInShell: any(named: 'runInShell'),
        ),
      ).thenAnswer((_) async => process);
      when(() => process.stdout).thenAnswer((_) => stdoutController.stream);
      when(() => process.stderr).thenAnswer((_) => stderrController.stream);
      when(() => process.exitCode).thenAnswer((_) async => 0);
      when(process.kill).thenReturn(true);
    });

    test('passes correct parameters to Process.start', () async {
      final events = <TestEvent>[];
      const arguments = ['--no-pub'];
      const environment = {'foo': 'bar'};
      const workingDirectory = './path/to/tests';
      const runInShell = true;
      final testEvents = dartTest(
        arguments: arguments,
        environment: environment,
        workingDirectory: workingDirectory,
        startProcess: testProcess.start,
        runInShell: runInShell,
      );
      final subscription = testEvents.listen(events.add);
      await stdoutController.close();
      expect(events, isEmpty);
      verify(
        () => testProcess.start(
          'dart',
          ['test', ...arguments, '--reporter=json'],
          workingDirectory: workingDirectory,
          environment: environment,
          runInShell: runInShell,
        ),
      ).called(1);
      unawaited(subscription.cancel());
    });

    test('emits error from stderr', () async {
      const expectedError = 'oops';
      final events = <TestEvent>[];
      final errors = <String>[];
      final testEvents = dartTest(startProcess: testProcess.start);
      final subscription = testEvents.listen(events.add, onError: errors.add);
      stderrController.add(utf8.encode(expectedError));
      await stdoutController.close();
      expect(events, isEmpty);
      expect(errors, equals([expectedError]));
      unawaited(subscription.cancel());
    });

    test('kills process when subscription is canceled', () async {
      final events = <TestEvent>[];
      final testEvents = dartTest(startProcess: testProcess.start);
      final subscription = testEvents.listen(events.add);
      await subscription.cancel();
      verify(process.kill).called(1);
    });

    test('emits correctly (e2e)', () async {
      final tempDirectory = Directory.systemTemp.createTempSync();
      File('${tempDirectory.path}/pubspec.yaml').writeAsStringSync('''
name: example
version: 0.1.0+1

environment:
  sdk: ">=2.12.0 <3.0.0"

dev_dependencies:
  test: any
''');
      final testDirectory = Directory('${tempDirectory.path}/test')
        ..createSync();
      File('${testDirectory.path}/example_test.dart').writeAsStringSync('''
import 'package:test/test.dart';

void main() {
  test('example', () {
    expect(true, isTrue);
  });
}
''');
      expect(
        dartTest(workingDirectory: tempDirectory.path)
            .where((e) => e is DoneTestEvent)
            .first,
        completes,
      );
    });
  });

  group('flutterTest', () {
    late StreamController<List<int>> stdoutController;
    late StreamController<List<int>> stderrController;
    late Process process;
    late TestProcess testProcess;

    setUp(() {
      stdoutController = StreamController();
      stderrController = StreamController();
      process = MockProcess();
      testProcess = MockTestProcess();
      when(
        () => testProcess.start(
          any(),
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
          includeParentEnvironment: any(named: 'includeParentEnvironment'),
          runInShell: any(named: 'runInShell'),
        ),
      ).thenAnswer((_) async => process);
      when(() => process.stdout).thenAnswer((_) => stdoutController.stream);
      when(() => process.stderr).thenAnswer((_) => stderrController.stream);
      when(() => process.exitCode).thenAnswer((_) async => 0);
      when(process.kill).thenReturn(true);
    });

    test('passes correct parameters to Process.start', () async {
      final events = <TestEvent>[];
      const arguments = ['--no-pub'];
      const environment = {'foo': 'bar'};
      const workingDirectory = './path/to/tests';
      const runInShell = true;
      final testEvents = flutterTest(
        arguments: arguments,
        environment: environment,
        workingDirectory: workingDirectory,
        startProcess: testProcess.start,
        runInShell: runInShell,
      );
      final subscription = testEvents.listen(events.add);
      await stdoutController.close();
      expect(events, isEmpty);
      verify(
        () => testProcess.start(
          'flutter',
          ['test', ...arguments, '--reporter=json'],
          workingDirectory: workingDirectory,
          environment: environment,
          runInShell: runInShell,
        ),
      ).called(1);
      unawaited(subscription.cancel());
    });

    test('emits error from stderr', () async {
      const expectedError = 'oops';
      final events = <TestEvent>[];
      final errors = <String>[];
      final testEvents = flutterTest(startProcess: testProcess.start);
      final subscription = testEvents.listen(events.add, onError: errors.add);
      stderrController.add(utf8.encode(expectedError));
      await stdoutController.close();
      expect(events, isEmpty);
      expect(errors, equals([expectedError]));
      unawaited(subscription.cancel());
    });

    test('kills process when subscription is canceled', () async {
      final events = <TestEvent>[];
      final testEvents = flutterTest(startProcess: testProcess.start);
      final subscription = testEvents.listen(events.add);
      await subscription.cancel();
      verify(process.kill).called(1);
    });

    test('emits correctly (e2e)', () async {
      final tempDirectory = Directory.systemTemp.createTempSync();
      File('${tempDirectory.path}/pubspec.yaml').writeAsStringSync('''
name: example
version: 0.1.0+1

environment:
  sdk: ">=2.12.0 <3.0.0"

dev_dependencies:
  test: any
''');
      final testDirectory = Directory('${tempDirectory.path}/test')
        ..createSync();
      File('${testDirectory.path}/example_a[1]_test.dart').writeAsStringSync('''
import 'package:test/test.dart';

void main() {
  test('example', () {
    expect(true, isTrue);
  });
}
''');
      expect(
        flutterTest(workingDirectory: tempDirectory.path)
            .where((e) => e is DoneTestEvent)
            .first,
        completes,
      );
    });

    test('emits correct stream of TestEvents', () async {
      final completer = Completer<int>();
      when(() => process.exitCode).thenAnswer((_) => completer.future);
      final rawEvents = [
        {
          'protocolVersion': '0.1.1',
          'runnerVersion': '1.20.1',
          'pid': 80881,
          'type': 'start',
          'time': 0,
        },
        {
          'suite': {
            'id': 0,
            'platform': 'vm',
            'path':
                'very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'suite',
          'time': 0,
        },
        {
          'test': {
            'id': 1,
            'name': 'loading very_good_test_runner/test/src/models/test_event_test.dart',
            'suiteID': 0,
            'groupIDs': <int>[],
            'metadata': {'skip': false, 'skipReason': null},
            'line': null,
            'column': null,
            'url': null,
          },
          'type': 'testStart',
          'time': 1,
        },
        {
          'suite': {
            'id': 2,
            'platform': 'vm',
            'path':
                'very_good_test_runner/test/src/flutter_test_runner_test.dart',
          },
          'type': 'suite',
          'time': 10,
        },
        {
          'test': {
            'id': 3,
            'name': 'loading very_good_test_runner/test/src/flutter_test_runner_test.dart',
            'suiteID': 2,
            'groupIDs': <int>[],
            'metadata': {'skip': false, 'skipReason': null},
            'line': null,
            'column': null,
            'url': null,
          },
          'type': 'testStart',
          'time': 11,
        },
        {'count': 2, 'time': 11, 'type': 'allSuites'},
        {
          'testID': 1,
          'result': 'success',
          'skipped': false,
          'hidden': true,
          'type': 'testDone',
          'time': 1058,
        },
        {
          'group': {
            'id': 4,
            'suiteID': 0,
            'parentID': null,
            'name': '',
            'metadata': {'skip': false, 'skipReason': null},
            'testCount': 11,
            'line': null,
            'column': null,
            'url': null,
          },
          'type': 'group',
          'time': 1064,
        },
        {
          'group': {
            'id': 5,
            'suiteID': 0,
            'parentID': 4,
            'name': 'TestEvent',
            'metadata': {'skip': false, 'skipReason': null},
            'testCount': 11,
            'line': 5,
            'column': 3,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'group',
          'time': 1066,
        },
        {
          'group': {
            'id': 6,
            'suiteID': 0,
            'parentID': 5,
            'name': 'TestEvent fromJson',
            'metadata': {'skip': false, 'skipReason': null},
            'testCount': 11,
            'line': 6,
            'column': 5,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'group',
          'time': 1067,
        },
        {
          'test': {
            'id': 7,
            'name': '''TestEvent fromJson throws UnsupportedError when object is not a supported test event''',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 7,
            'column': 7,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'testStart',
          'time': 1067,
        },
        {
          'testID': 3,
          'result': 'success',
          'skipped': false,
          'hidden': true,
          'type': 'testDone',
          'time': 1074,
        },
        {
          'group': {
            'id': 8,
            'suiteID': 2,
            'parentID': null,
            'name': '',
            'metadata': {'skip': false, 'skipReason': null},
            'testCount': 3,
            'line': null,
            'column': null,
            'url': null,
          },
          'type': 'group',
          'time': 1074,
        },
        {
          'group': {
            'id': 9,
            'suiteID': 2,
            'parentID': 8,
            'name': 'flutterTest',
            'metadata': {'skip': false, 'skipReason': null},
            'testCount': 3,
            'line': 27,
            'column': 3,
            'url': 'file://very_good_test_runner/test/src/flutter_test_runner_test.dart',
          },
          'type': 'group',
          'time': 1074,
        },
        {
          'test': {
            'id': 10,
            'name': 'flutterTest passes correct parameters to Process.start',
            'suiteID': 2,
            'groupIDs': [8, 9],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 53,
            'column': 5,
            'url': 'file://very_good_test_runner/test/src/flutter_test_runner_test.dart',
          },
          'type': 'testStart',
          'time': 1075,
        },
        {
          'testID': 7,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1125,
        },
        {
          'test': {
            'id': 11,
            'name':
                'TestEvent fromJson returns StartTestEvent when type is start',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 20,
            'column': 7,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'testStart',
          'time': 1125,
        },
        {
          'testID': 11,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1132,
        },
        {
          'test': {
            'id': 12,
            'name':
                'TestEvent fromJson returns SuiteTestEvent when type is suite',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 31,
            'column': 7,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'testStart',
          'time': 1133,
        },
        {
          'testID': 12,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1138,
        },
        {
          'test': {
            'id': 13,
            'name':
                'TestEvent fromJson returns GroupTestEvent when type is group',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 44,
            'column': 7,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'testStart',
          'time': 1139,
        },
        {
          'testID': 13,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1148,
        },
        {
          'test': {
            'id': 14,
            'name': '''TestEvent fromJson returns TestStartEvent when type is testStart''',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 64,
            'column': 7,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'testStart',
          'time': 1148,
        },
        {
          'testID': 14,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1155,
        },
        {
          'test': {
            'id': 15,
            'name': '''TestEvent fromJson returns AllSuitesTestEvent when type is allSuites''',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 83,
            'column': 7,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'testStart',
          'time': 1155,
        },
        {
          'testID': 15,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1160,
        },
        {
          'test': {
            'id': 16,
            'name':
                'TestEvent fromJson returns ErrorTestEvent when type is error',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 89,
            'column': 7,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'testStart',
          'time': 1160,
        },
        {
          'testID': 16,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1167,
        },
        {
          'test': {
            'id': 17,
            'name': '''TestEvent fromJson returns MessageTestEvent when type is print''',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 103,
            'column': 7,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'testStart',
          'time': 1168,
        },
        {
          'testID': 17,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1176,
        },
        {
          'test': {
            'id': 18,
            'name':
                'TestEvent fromJson returns DebugTestEvent when type is debug',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 116,
            'column': 7,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'testStart',
          'time': 1176,
        },
        {
          'testID': 10,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1179,
        },
        {
          'test': {
            'id': 19,
            'name': 'flutterTest emits error from stderr',
            'suiteID': 2,
            'groupIDs': [8, 9],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 81,
            'column': 5,
            'url': 'file://very_good_test_runner/test/src/flutter_test_runner_test.dart',
          },
          'type': 'testStart',
          'time': 1179,
        },
        {
          'testID': 18,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1183,
        },
        {
          'test': {
            'id': 20,
            'name': '''TestEvent fromJson returns TestDoneEvent when type is testDone''',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 128,
            'column': 7,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'testStart',
          'time': 1184,
        },
        {
          'testID': 19,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1192,
        },
        {
          'test': {
            'id': 21,
            'name': 'flutterTest kills process when subscription is canceled',
            'suiteID': 2,
            'groupIDs': [8, 9],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 94,
            'column': 5,
            'url': 'file://very_good_test_runner/test/src/flutter_test_runner_test.dart',
          },
          'type': 'testStart',
          'time': 1192,
        },
        {
          'testID': 20,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1193,
        },
        {
          'test': {
            'id': 22,
            'name':
                'TestEvent fromJson returns DoneTestEvent when type is done',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 141,
            'column': 7,
            'url': 'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'testStart',
          'time': 1194,
        },
        {
          'testID': 22,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1199,
        },
        {
          'testID': 21,
          'result': 'success',
          'skipped': false,
          'hidden': false,
          'type': 'testDone',
          'time': 1199,
        },
        {'success': true, 'type': 'done', 'time': 1229},
      ];
      final events = <TestEvent>[];
      final testEvents = flutterTest(startProcess: testProcess.start);
      final subscription = testEvents.listen(events.add);
      final encodedEvents = rawEvents.map(
        (element) => utf8.encode('${json.encode(element)}\n'),
      );
      await stdoutController.addStream(Stream.fromIterable(encodedEvents));
      expect(
        events,
        equals([
          isA<StartTestEvent>(),
          isA<SuiteTestEvent>(),
          isA<TestStartEvent>(),
          isA<SuiteTestEvent>(),
          isA<TestStartEvent>(),
          isA<AllSuitesTestEvent>(),
          isA<TestDoneEvent>(),
          isA<GroupTestEvent>(),
          isA<GroupTestEvent>(),
          isA<GroupTestEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<GroupTestEvent>(),
          isA<GroupTestEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestStartEvent>(),
          isA<TestDoneEvent>(),
          isA<TestDoneEvent>(),
          isA<DoneTestEvent>(),
        ]),
      );
      completer.complete(0);
      // Simulate the process closing its pipes on exit.
      await stderrController.close();
      await stdoutController.close();
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isA<ExitTestEvent>());
      unawaited(subscription.cancel());
    });

    test('emits events split across stdout chunks', () async {
      final completer = Completer<int>();
      when(() => process.exitCode).thenAnswer((_) => completer.future);
      final events = <TestEvent>[];
      final testEvents = flutterTest(startProcess: testProcess.start);
      final subscription = testEvents.listen(events.add);
      final bytes = utf8.encode(
        '${json.encode({
          'test': {
            'id': 1,
            'name': 'ünïcödé',
            'suiteID': 0,
            'groupIDs': <int>[],
            'metadata': {'skip': false, 'skipReason': null},
            'line': null,
            'column': null,
            'url': null,
          },
          'type': 'testStart',
          'time': 0,
        })}\n'
        '${json.encode({'success': true, 'type': 'done', 'time': 1})}\n',
      );
      final multiByte = bytes.indexOf(0xc3);
      await stdoutController.addStream(
        Stream.fromIterable([
          bytes.sublist(0, multiByte + 1),
          bytes.sublist(multiByte + 1, 50),
          bytes.sublist(50),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        events,
        equals([
          isA<TestStartEvent>().having((e) => e.test.name, 'name', 'ünïcödé'),
          isA<DoneTestEvent>(),
        ]),
      );
      completer.complete(0);
      unawaited(subscription.cancel());
    });

    test(
      'drains buffered events and closes the stream when the process exits',
      () async {
        final completer = Completer<int>();
        when(() => process.exitCode).thenAnswer((_) => completer.future);
        final events = <TestEvent>[];
        var done = false;
        flutterTest(startProcess: testProcess.start)
            .listen(events.add, onDone: () => done = true);

        final rawEvents = [
          {
            'protocolVersion': '0.1.1',
            'runnerVersion': '1.20.1',
            'pid': 80881,
            'type': 'start',
            'time': 0,
          },
          {'success': true, 'type': 'done', 'time': 1},
        ];
        final encodedEvents = rawEvents.map(
          (element) => utf8.encode('${json.encode(element)}\n'),
        );

        // Simulate the process closing its pipes on exit.
        completer.complete(0);
        await stdoutController.addStream(Stream.fromIterable(encodedEvents));
        await stderrController.close();
        await stdoutController.close();
        await Future<void>.delayed(Duration.zero);

        expect(
          events,
          equals([
            isA<StartTestEvent>(),
            isA<DoneTestEvent>(),
            isA<ExitTestEvent>(),
          ]),
        );
        expect(done, isTrue);
      },
    );
  });

  group('cancellation', () {
    // A non-default grace period, so the tests check that it is forwarded.
    const gracePeriod = Duration(seconds: 5);
    // Mirrors `_reapTimeout` in lib/src/very_good_test_runner.dart: the time
    // the process gets after each escalation signal.
    const reapTimeout = Duration(seconds: 1);
    const tick = Duration(milliseconds: 1);
    const sigterm = ProcessSignal.sigterm;
    const sigkill = ProcessSignal.sigkill;

    for (final MapEntry(key: name, value: runTests) in _testRunners.entries) {
      group(name, () {
        /// Runs the tests against [process] and listens to the events.
        ///
        /// When [gracePeriod] is `null` the default grace period is used.
        StreamSubscription<TestEvent> listen(
          FakeProcess process, {
          Duration? gracePeriod,
          Future<void>? started,
          void Function(TestEvent)? onData,
          void Function()? onDone,
        }) {
          final startProcess = _startProcessReturning(
            process,
            started: started,
          );
          final events = gracePeriod == null
              ? runTests(startProcess: startProcess)
              : runTests(gracePeriod: gracePeriod, startProcess: startProcess);
          return events.listen(onData, onDone: onDone);
        }

        // The escalation timing is driven with `fakeAsync`, so the grace
        // period and reap timeouts never use real timers. Cancelling a pipe
        // subscription returns a future bound to the root zone, so the future
        // returned by `cancel()` cannot complete inside `fakeAsync`; the
        // real-async tests further down cover when it completes.
        group('escalation', () {
          test('sends a single SIGTERM when the process exits on it', () {
            fakeAsync((async) {
              final process = FakeProcess(exitAfterSignals: 1);
              final subscription = listen(process, gracePeriod: gracePeriod);
              async.flushMicrotasks();

              unawaited(subscription.cancel());
              async.flushMicrotasks();
              expect(process.killSignals, [sigterm]);

              async.elapse(gracePeriod + reapTimeout * 2);
              expect(process.killSignals, [sigterm]);
            });
          });

          test('waits the grace period before a second SIGTERM', () {
            fakeAsync((async) {
              final process = FakeProcess(exitAfterSignals: 2);
              final subscription = listen(process, gracePeriod: gracePeriod);
              async.flushMicrotasks();

              unawaited(subscription.cancel());
              async.elapse(gracePeriod - tick);
              expect(process.killSignals, [sigterm]);

              async.elapse(tick);
              expect(process.killSignals, [sigterm, sigterm]);

              async.elapse(reapTimeout * 2);
              expect(process.killSignals, [sigterm, sigterm]);
            });
          });

          test('uses a 2 second grace period by default', () {
            fakeAsync((async) {
              final process = FakeProcess(exitAfterSignals: 2);
              final subscription = listen(process);
              async.flushMicrotasks();

              unawaited(subscription.cancel());
              async.elapse(const Duration(seconds: 2) - tick);
              expect(process.killSignals, [sigterm]);

              async.elapse(tick);
              expect(process.killSignals, [sigterm, sigterm]);
            });
          });

          test(
            'sends SIGKILL when both SIGTERMs are ignored, then stops waiting',
            () {
              fakeAsync((async) {
                final process = FakeProcess();
                final subscription = listen(process, gracePeriod: gracePeriod);
                async.flushMicrotasks();

                unawaited(subscription.cancel());
                async.elapse(gracePeriod);
                expect(process.killSignals, [sigterm, sigterm]);

                async.elapse(reapTimeout - tick);
                expect(process.killSignals, [sigterm, sigterm]);

                async.elapse(tick);
                expect(process.killSignals, [sigterm, sigterm, sigkill]);
                expect(process.stderrController.hasListener, isTrue);

                // The process never exits, yet once the last reap timeout runs
                // out cancellation moves on to the pipes, with no further
                // signals or timers.
                async.elapse(reapTimeout);
                expect(process.stderrController.hasListener, isFalse);

                async.elapse(reapTimeout * 10);
                expect(process.killSignals, [sigterm, sigterm, sigkill]);
                expect(async.pendingTimers, isEmpty);
              });
            },
          );
        });

        test('completes cancel only after the process has exited', () async {
          final process = FakeProcess();
          final subscription = listen(process, gracePeriod: gracePeriod);
          await pumpEventQueue();

          var cancelled = false;
          final cancellation = subscription.cancel().then(
            (_) => cancelled = true,
          );
          await pumpEventQueue();

          expect(process.killSignals, [sigterm]);
          expect(cancelled, isFalse);

          process.terminate();
          await cancellation;

          expect(process.stdoutController.hasListener, isFalse);
          expect(process.stderrController.hasListener, isFalse);
        });

        test(
          'sends SIGTERM once the process starts when cancelled before',
          () async {
            final process = FakeProcess(exitAfterSignals: 1);
            final started = Completer<void>();
            final subscription = listen(
              process,
              gracePeriod: gracePeriod,
              started: started.future,
            );

            final cancellation = subscription.cancel();
            await pumpEventQueue();

            // No signal can be sent before there is a process.
            expect(process.killSignals, isEmpty);

            started.complete();
            await cancellation;

            expect(process.killSignals, [sigterm]);
          },
        );

        test('sends no signal when the process exits on its own', () async {
          final process = FakeProcess();
          final events = <TestEvent>[];
          final done = Completer<void>();
          listen(
            process,
            gracePeriod: gracePeriod,
            onData: events.add,
            onDone: done.complete,
          );
          await pumpEventQueue();

          process.terminate();
          await done.future;

          expect(events, [isA<ExitTestEvent>()]);
          expect(process.killSignals, isEmpty);
        });
      });
    }
  });
}
