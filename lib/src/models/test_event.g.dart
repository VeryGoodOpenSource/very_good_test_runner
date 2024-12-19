// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: document_ignores, implicit_dynamic_parameter, cast_nullable_to_non_nullable, require_trailing_commas, lines_longer_than_80_chars

part of 'test_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StartTestEvent _$StartTestEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StartTestEvent',
      json,
      ($checkedConvert) {
        final val = StartTestEvent(
          protocolVersion:
              $checkedConvert('protocolVersion', (v) => v as String),
          runnerVersion: $checkedConvert('runnerVersion', (v) => v as String?),
          pid: $checkedConvert('pid', (v) => (v as num).toInt()),
          time: $checkedConvert('time', (v) => (v as num).toInt()),
        );
        return val;
      },
    );

AllSuitesTestEvent _$AllSuitesTestEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AllSuitesTestEvent',
      json,
      ($checkedConvert) {
        final val = AllSuitesTestEvent(
          count: $checkedConvert('count', (v) => (v as num).toInt()),
          time: $checkedConvert('time', (v) => (v as num).toInt()),
        );
        return val;
      },
    );

SuiteTestEvent _$SuiteTestEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SuiteTestEvent',
      json,
      ($checkedConvert) {
        final val = SuiteTestEvent(
          suite: $checkedConvert(
              'suite', (v) => TestSuite.fromJson(v as Map<String, dynamic>)),
          time: $checkedConvert('time', (v) => (v as num).toInt()),
        );
        return val;
      },
    );

DebugTestEvent _$DebugTestEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'DebugTestEvent',
      json,
      ($checkedConvert) {
        final val = DebugTestEvent(
          suiteID: $checkedConvert('suiteID', (v) => (v as num).toInt()),
          observatory: $checkedConvert('observatory', (v) => v as String?),
          remoteDebugger:
              $checkedConvert('remoteDebugger', (v) => v as String?),
          time: $checkedConvert('time', (v) => (v as num).toInt()),
        );
        return val;
      },
    );

GroupTestEvent _$GroupTestEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'GroupTestEvent',
      json,
      ($checkedConvert) {
        final val = GroupTestEvent(
          group: $checkedConvert(
              'group', (v) => TestGroup.fromJson(v as Map<String, dynamic>)),
          time: $checkedConvert('time', (v) => (v as num).toInt()),
        );
        return val;
      },
    );

TestStartEvent _$TestStartEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'TestStartEvent',
      json,
      ($checkedConvert) {
        final val = TestStartEvent(
          test: $checkedConvert(
              'test', (v) => Test.fromJson(v as Map<String, dynamic>)),
          time: $checkedConvert('time', (v) => (v as num).toInt()),
        );
        return val;
      },
    );

MessageTestEvent _$MessageTestEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'MessageTestEvent',
      json,
      ($checkedConvert) {
        final val = MessageTestEvent(
          testID: $checkedConvert('testID', (v) => (v as num).toInt()),
          messageType: $checkedConvert('messageType', (v) => v as String),
          message: $checkedConvert('message', (v) => v as String),
          time: $checkedConvert('time', (v) => (v as num).toInt()),
        );
        return val;
      },
    );

ErrorTestEvent _$ErrorTestEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ErrorTestEvent',
      json,
      ($checkedConvert) {
        final val = ErrorTestEvent(
          testID: $checkedConvert('testID', (v) => (v as num).toInt()),
          error: $checkedConvert('error', (v) => v as String),
          stackTrace: $checkedConvert('stackTrace', (v) => v as String),
          isFailure: $checkedConvert('isFailure', (v) => v as bool),
          time: $checkedConvert('time', (v) => (v as num).toInt()),
        );
        return val;
      },
    );

TestDoneEvent _$TestDoneEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'TestDoneEvent',
      json,
      ($checkedConvert) {
        final val = TestDoneEvent(
          testID: $checkedConvert('testID', (v) => (v as num).toInt()),
          result: $checkedConvert(
              'result', (v) => $enumDecode(_$TestResultEnumMap, v)),
          hidden: $checkedConvert('hidden', (v) => v as bool),
          skipped: $checkedConvert('skipped', (v) => v as bool),
          time: $checkedConvert('time', (v) => (v as num).toInt()),
        );
        return val;
      },
    );

const _$TestResultEnumMap = {
  TestResult.success: 'success',
  TestResult.failure: 'failure',
  TestResult.error: 'error',
};

DoneTestEvent _$DoneTestEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'DoneTestEvent',
      json,
      ($checkedConvert) {
        final val = DoneTestEvent(
          success: $checkedConvert('success', (v) => v as bool?),
          time: $checkedConvert('time', (v) => (v as num).toInt()),
        );
        return val;
      },
    );

ExitTestEvent _$ExitTestEventFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ExitTestEvent',
      json,
      ($checkedConvert) {
        final val = ExitTestEvent(
          time: $checkedConvert('time', (v) => (v as num).toInt()),
          exitCode: $checkedConvert('exitCode', (v) => (v as num).toInt()),
        );
        return val;
      },
    );

TestSuite _$TestSuiteFromJson(Map<String, dynamic> json) => $checkedCreate(
      'TestSuite',
      json,
      ($checkedConvert) {
        final val = TestSuite(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          platform: $checkedConvert('platform', (v) => v as String),
          path: $checkedConvert('path', (v) => v as String?),
        );
        return val;
      },
    );

TestGroup _$TestGroupFromJson(Map<String, dynamic> json) => $checkedCreate(
      'TestGroup',
      json,
      ($checkedConvert) {
        final val = TestGroup(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          name: $checkedConvert('name', (v) => v as String),
          suiteID: $checkedConvert('suiteID', (v) => (v as num).toInt()),
          testCount: $checkedConvert('testCount', (v) => (v as num).toInt()),
          metadata: $checkedConvert('metadata',
              (v) => TestMetadata.fromJson(v as Map<String, dynamic>)),
          parentID: $checkedConvert('parentID', (v) => (v as num?)?.toInt()),
          line: $checkedConvert('line', (v) => (v as num?)?.toInt()),
          column: $checkedConvert('column', (v) => (v as num?)?.toInt()),
          url: $checkedConvert('url', (v) => v as String?),
        );
        return val;
      },
    );

TestMetadata _$TestMetadataFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'TestMetadata',
      json,
      ($checkedConvert) {
        final val = TestMetadata(
          skip: $checkedConvert('skip', (v) => v as bool),
          skipReason: $checkedConvert('skipReason', (v) => v as String?),
        );
        return val;
      },
    );

Test _$TestFromJson(Map<String, dynamic> json) => $checkedCreate(
      'Test',
      json,
      ($checkedConvert) {
        final val = Test(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          name: $checkedConvert('name', (v) => v as String),
          suiteID: $checkedConvert('suiteID', (v) => (v as num).toInt()),
          groupIDs: $checkedConvert(
              'groupIDs',
              (v) =>
                  (v as List<dynamic>).map((e) => (e as num).toInt()).toList()),
          metadata: $checkedConvert('metadata',
              (v) => TestMetadata.fromJson(v as Map<String, dynamic>)),
          line: $checkedConvert('line', (v) => (v as num?)?.toInt()),
          column: $checkedConvert('column', (v) => (v as num?)?.toInt()),
          url: $checkedConvert('url', (v) => v as String?),
          rootLine: $checkedConvert('rootLine', (v) => (v as num?)?.toInt()),
          rootColumn:
              $checkedConvert('rootColumn', (v) => (v as num?)?.toInt()),
          rootUrl: $checkedConvert('rootUrl', (v) => v as String?),
        );
        return val;
      },
    );
