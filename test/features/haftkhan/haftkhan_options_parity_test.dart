// Parity port of tests/JameJam.Tests/HaftKhan/HaftKhanOptionsTests.cs (20 cases).
//
// Proves nothing is hardcoded: every Haft Khan knob flows from guard-validated
// HaftKhanOptions into the service and the AI prompts. The .NET cases drive the CLI as the
// last hop; here the last hop is the service and the assistant, which is what the GUI calls.
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/haftkhan/ai_task_assistant.dart';
import 'package:jamejam/features/haftkhan/haftkhan_service.dart';
import 'package:jamejam/features/haftkhan/models.dart';
import 'package:jamejam/features/haftkhan/task_guard.dart';
import 'package:jamejam/features/haftkhan/task_repository.dart';

HaftKhanTask sampleTask() => HaftKhanTask(
  id: 1,
  title: 'Slay the dragon',
  notes: 'with Rakhsh',
  createdAt: DateTime.utc(2026, 9, 19),
  updatedAt: DateTime.utc(2026, 9, 19),
);

void main() {
  // Defaults_AreValid
  test('default options are valid', () {
    expect(const HaftKhanOptions().validate, returnsNormally);
  });

  // Validate_RejectsOutOfRangeTitleLimit
  test('a title limit outside its rail is rejected', () {
    for (final value in [0, -1, 10001]) {
      expect(
        () => HaftKhanOptions(maxTitleLength: value).validate(),
        throwsA(isA<RangeError>()),
        reason: '$value',
      );
    }
  });

  // Validate_RejectsOutOfRangeNotesLimit
  test('a notes limit outside its rail is rejected', () {
    for (final value in [0, 100001]) {
      expect(
        () => HaftKhanOptions(maxNotesLength: value).validate(),
        throwsA(isA<RangeError>()),
      );
    }
  });

  // Validate_RejectsMaxTasksBelowOne
  test('a summary cap below one is rejected', () {
    expect(
      () => const HaftKhanOptions(maxTasksInSummary: 0).validate(),
      throwsA(isA<RangeError>()),
    );
  });

  // Validate_RejectsMinSubtasksBelowOne
  test('a minimum subtask count below one is rejected', () {
    expect(
      () => const HaftKhanOptions(breakdownMinSubtasks: 0).validate(),
      throwsA(isA<RangeError>()),
    );
  });

  // Validate_RejectsOutOfRangeNotesPromptCap
  test('a notes prompt cap outside its rail is rejected', () {
    for (final value in [0, 32001]) {
      expect(
        () => HaftKhanOptions(maxNotesInPrompt: value).validate(),
        throwsA(isA<RangeError>()),
      );
    }
  });

  // Validate_RejectsBrokenSubtaskRange
  test('a minimum above the maximum is rejected', () {
    expect(
      () => const HaftKhanOptions(
        breakdownMinSubtasks: 5,
        breakdownMaxSubtasks: 2,
      ).validate(),
      throwsA(isA<RangeError>()),
    );
  });

  // Validate_RejectsEveryRailFloor
  test('every rail rejects its floor value', () {
    final cases = <String, HaftKhanOptions>{
      'maxTagsPerTask': const HaftKhanOptions(maxTagsPerTask: 0),
      'maxTagLength': const HaftKhanOptions(maxTagLength: 0),
      'maxRecurrenceInterval': const HaftKhanOptions(maxRecurrenceInterval: 0),
      'maxUndoDepth': const HaftKhanOptions(maxUndoDepth: 0),
      'boardTasksPerColumn': const HaftKhanOptions(boardTasksPerColumn: 0),
      'reviewFocusCount': const HaftKhanOptions(reviewFocusCount: 0),
      'maxImportTasks': const HaftKhanOptions(maxImportTasks: 0),
    };

    for (final entry in cases.entries) {
      expect(
        entry.value.validate,
        throwsA(isA<RangeError>()),
        reason: entry.key,
      );
    }
  });

  // Service_EnforcesCustomTitleLimit
  test('the service enforces a custom title limit', () async {
    final service = HaftKhanService(
      repository: MemoryTaskRepository(),
      clock: DateTime.now,
      options: const HaftKhanOptions(maxTitleLength: 5),
    );

    expect((await service.addTask(title: '12345')).title.length, 5);
    expect(() => service.addTask(title: '123456'), throwsA(isA<RangeError>()));
  });

  // Service_EnforcesCustomNotesLimit
  test('the service enforces a custom notes limit', () async {
    final service = HaftKhanService(
      repository: MemoryTaskRepository(),
      clock: DateTime.now,
      options: const HaftKhanOptions(maxNotesLength: 4),
    );

    expect(
      () => service.addTask(title: 't', notes: 'too long'),
      throwsA(isA<RangeError>()),
    );
  });

  // Assistant_UsesCustomSummaryCap
  test('the assistant honours a custom summary cap', () {
    final assistant = AiTaskAssistant(
      const HaftKhanOptions(maxTasksInSummary: 2),
    );
    final tasks = [
      for (var index = 1; index <= 5; index++)
        sampleTask().copyWith(id: index, title: 'task $index'),
    ];

    final prompt = assistant.buildSummaryPrompt(tasks);

    expect(prompt, contains('#2 '));
    expect(prompt, isNot(contains('#3 ')));
    expect(prompt, contains('3 more tasks omitted'));
  });

  // Assistant_UsesCustomSubtaskRange
  test('the assistant honours a custom subtask range', () {
    const assistant = AiTaskAssistant(
      HaftKhanOptions(breakdownMinSubtasks: 2, breakdownMaxSubtasks: 4),
    );

    expect(
      assistant.buildBreakdownPrompt(sampleTask()),
      contains('into 2 to 4 short, actionable subtasks'),
    );
  });

  // Assistant_UsesCustomNotesPromptCap
  test('the assistant honours a custom notes cap inside prompts', () {
    const assistant = AiTaskAssistant(HaftKhanOptions(maxNotesInPrompt: 10));

    final prompt = assistant.buildBreakdownPrompt(
      sampleTask().copyWith(notes: 'n' * 50),
    );

    expect(prompt, contains('nnnnnnnnnn…')); // 10 characters + ellipsis
  });

  // App_FlowsCustomOptionsThroughToTheCommands
  test('a bad title fails fast with the custom rail in the message', () async {
    final service = HaftKhanService(
      repository: MemoryTaskRepository(),
      clock: DateTime.now,
      options: const HaftKhanOptions(maxTitleLength: 5),
    );

    await expectLater(
      service.addTask(title: 'too long title'),
      throwsA(
        isA<RangeError>().having(
          (error) => error.message.toString(),
          'message',
          contains('5'),
        ),
      ),
    );
  });
}
