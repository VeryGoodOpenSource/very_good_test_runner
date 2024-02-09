import 'dart:async';
import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';
import 'package:very_good_test_runner/very_good_test_runner.dart';

// ignore: one_member_abstracts
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

class MockTestProcess extends Mock implements TestProcess {}

class MockProcess extends Mock implements Process {}

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
      File('${tempDirectory.path}/pubspec.yaml').writeAsStringSync(
        '''
name: example
version: 0.1.0+1

environment:
  sdk: ">=2.12.0 <3.0.0"

dev_dependencies:
  test: any
''',
      );
      final testDirectory = Directory('${tempDirectory.path}/test')
        ..createSync();
      File('${testDirectory.path}/example_test.dart').writeAsStringSync(
        '''
import 'package:test/test.dart';

void main() {
  test('example', () {
    expect(true, isTrue);
  });
}
''',
      );
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
      File('${tempDirectory.path}/pubspec.yaml').writeAsStringSync(
        '''
name: example
version: 0.1.0+1

environment:
  sdk: ">=2.12.0 <3.0.0"

dev_dependencies:
  test: any
''',
      );
      final testDirectory = Directory('${tempDirectory.path}/test')
        ..createSync();
      File('${testDirectory.path}/example_a[1]_test.dart').writeAsStringSync(
        '''
import 'package:test/test.dart';

void main() {
  test('example', () {
    expect(true, isTrue);
  });
}
''',
      );
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
            'name':
                'loading very_good_test_runner/test/src/models/test_event_test.dart',
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
            'name':
                'loading very_good_test_runner/test/src/flutter_test_runner_test.dart',
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
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
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
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
          },
          'type': 'group',
          'time': 1067,
        },
        {
          'test': {
            'id': 7,
            'name':
                '''TestEvent fromJson throws UnsupportedError when object is not a supported test event''',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 7,
            'column': 7,
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
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
            'url':
                'file://very_good_test_runner/test/src/flutter_test_runner_test.dart',
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
            'url':
                'file://very_good_test_runner/test/src/flutter_test_runner_test.dart',
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
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
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
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
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
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
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
            'name':
                '''TestEvent fromJson returns TestStartEvent when type is testStart''',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 64,
            'column': 7,
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
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
            'name':
                '''TestEvent fromJson returns AllSuitesTestEvent when type is allSuites''',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 83,
            'column': 7,
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
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
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
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
            'name':
                '''TestEvent fromJson returns MessageTestEvent when type is print''',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 103,
            'column': 7,
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
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
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
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
            'url':
                'file://very_good_test_runner/test/src/flutter_test_runner_test.dart',
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
            'name':
                '''TestEvent fromJson returns TestDoneEvent when type is testDone''',
            'suiteID': 0,
            'groupIDs': [4, 5, 6],
            'metadata': {'skip': false, 'skipReason': null},
            'line': 128,
            'column': 7,
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
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
            'url':
                'file://very_good_test_runner/test/src/flutter_test_runner_test.dart',
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
            'url':
                'file://very_good_test_runner/test/src/models/test_event_test.dart',
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
        (element) => utf8.encode(json.encode(element)),
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
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isA<ExitTestEvent>());
      unawaited(subscription.cancel());
    });
  });
}
