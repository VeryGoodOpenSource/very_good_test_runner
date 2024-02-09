import 'package:test/test.dart';
import 'package:very_good_test_runner/very_good_test_runner.dart';

void main() {
  group('TestEvent', () {
    group('fromJson', () {
      test(
          'throws UnsupportedError '
          'when object is not a supported test event', () {
        expect(
          () => TestEvent.fromJson(<String, dynamic>{}),
          throwsUnsupportedError,
        );
        expect(
          () => TestEvent.fromJson(<String, dynamic>{'type': 'invalid'}),
          throwsUnsupportedError,
        );
      });

      test('returns StartTestEvent when type is start', () {
        final json = {
          'protocolVersion': '0.1.1',
          'runnerVersion': '1.19.5',
          'pid': 67090,
          'type': 'start',
          'time': 0,
        };
        expect(TestEvent.fromJson(json), isA<StartTestEvent>());
      });

      test('returns SuiteTestEvent when type is suite', () {
        final json = {
          'suite': {
            'id': 0,
            'platform': 'vm',
            'path': '/example/test/app/view/app_test.dart',
          },
          'type': 'suite',
          'time': 0,
        };
        expect(TestEvent.fromJson(json), isA<SuiteTestEvent>());
      });

      test('returns GroupTestEvent when type is group', () {
        final json = {
          'group': {
            'id': 6,
            'suiteID': 0,
            'parentID': null,
            'name': '',
            'metadata': {'skip': false, 'skipReason': null},
            'testCount': 1,
            'line': null,
            'column': null,
            'url': null,
          },
          'type': 'group',
          'time': 2599,
        };

        expect(TestEvent.fromJson(json), isA<GroupTestEvent>());
      });

      test('returns TestStartEvent when type is testStart', () {
        final json = {
          'test': {
            'id': 1,
            'name': 'loading /example/test/app/view/app_test.dart',
            'suiteID': 0,
            'groupIDs': <int>[],
            'metadata': {'skip': false, 'skipReason': null},
            'line': null,
            'column': null,
            'url': null,
          },
          'type': 'testStart',
          'time': 1,
        };

        expect(TestEvent.fromJson(json), isA<TestStartEvent>());
      });

      test('returns AllSuitesTestEvent when type is allSuites', () {
        final json = {'count': 3, 'time': 10, 'type': 'allSuites'};

        expect(TestEvent.fromJson(json), isA<AllSuitesTestEvent>());
      });

      test('returns ErrorTestEvent when type is error', () {
        final json = {
          'testID': 8,
          'error':
              '''Test failed. See exception logs above.\nThe test description was: renders CounterPage''',
          'stackTrace': '',
          'isFailure': false,
          'type': 'error',
          'time': 3288,
        };

        expect(TestEvent.fromJson(json), isA<ErrorTestEvent>());
      });

      test('returns MessageTestEvent when type is print', () {
        final json = {
          'testID': 8,
          'messageType': 'print',
          'message':
              '''══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════\nThe following TestFailure was thrown running a test:\nExpected: no matching nodes in the widget tree\n  Actual: _WidgetTypeFinder:<exactly one widget with type 'CounterPage' (ignoring offstage widgets):\nCounterPage>\n   Which: means one was found but none were expected\n\nWhen the exception was thrown, this was the stack:\n#4      main.<anonymous closure>.<anonymous closure> (file:///example/test/app/view/app_test.dart:16:7)\n<asynchronous suspension>\n<asynchronous suspension>\n(elided one frame from package:stack_trace)\n\nThis was caught by the test expectation on the following line:\n  file:///example/test/app/view/app_test.dart line 16\nThe test description was:\n  renders CounterPage\n════════════════════════════════════════════════════════════════════════════════════════════════════''',
          'type': 'print',
          'time': 3284,
        };

        expect(TestEvent.fromJson(json), isA<MessageTestEvent>());
      });

      test('returns DebugTestEvent when type is debug', () {
        final json = {
          'suiteID': 0,
          'type': 'debug',
          'observatory': null,
          'remoteDebugger': null,
          'time': 3288,
        };

        expect(TestEvent.fromJson(json), isA<DebugTestEvent>());
      });

      test('returns TestDoneEvent when type is testDone', () {
        final json = {
          'testID': 1,
          'result': 'success',
          'skipped': false,
          'hidden': true,
          'type': 'testDone',
          'time': 2593,
        };

        expect(TestEvent.fromJson(json), isA<TestDoneEvent>());
      });

      test('returns DoneTestEvent when type is done', () {
        final json = {'success': true, 'type': 'done', 'time': 4034};

        expect(TestEvent.fromJson(json), isA<DoneTestEvent>());
      });

      test('returns ExitTestEvent when type is exit', () {
        final json = {'exitCode': 0, 'type': 'exit', 'time': 4034};

        expect(TestEvent.fromJson(json), isA<ExitTestEvent>());
      });
    });
  });
}
