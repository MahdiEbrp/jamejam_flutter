import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/ganjoor/ganjoor_options.dart';
import 'package:jamejam/features/ganjoor/ganjoor_service.dart';
import 'package:jamejam/features/ganjoor/ganjoor_store.dart';
import 'package:jamejam/features/ganjoor/models.dart';
import 'package:jamejam/features/ganjoor/money.dart';
import 'package:jamejam/features/ganjoor/sqlite_ganjoor_store.dart';

/// Port of `tests/JameJam.Tests/Ganjoor/GanjoorUndoAndFailurePathTests.cs` (9 cases).
///
/// The four CLI cases of that file (usage lines, exit codes, the IO error wrapper, the AI
/// gate) live on the screen now: `ganjoor_controller_test.dart` covers the account
/// lifecycle through `GanjoorController` and the AI gate against a null funnel, and
/// `ganjoor_page_test.dart` covers the dialogs that replace the flags.
void main() {
  DateTime clock() => DateTime.utc(2026, 9, 19, 10);

  test('MemoryStore_TrimsOldestSnapshots_BeyondTheDepth', () async {
    final store = MemoryGanjoorStore()..undoDepth = 3;
    expect(store.undoDepth, 3);

    for (var i = 1; i <= 5; i++) {
      await store.pushUndo('s$i');
      expect(await store.undoCount, i < 3 ? i : 3);
    }

    expect(await store.popUndo(), 's5'); // newest first
    expect(await store.popUndo(), 's4');
    expect(await store.popUndo(), 's3');
    expect(await store.popUndo(), isNull); // s1 and s2 were trimmed away
  });

  test('MemoryStore_RejectsNegativeDepth', () {
    expect(() => MemoryGanjoorStore()..undoDepth = -1, throwsRangeError);
  });

  test('SqliteStore_TrimsOldestSnapshots_BeyondTheDepth', () async {
    final directory = Directory.systemTemp.createTempSync('ganjoor-undo');
    try {
      final store = SqliteGanjoorStore('${directory.path}/undo.db')
        ..undoDepth = 2;
      await store.pushUndo('old');
      await store.pushUndo('mid');
      await store.pushUndo('new');
      expect(await store.undoCount, 2);
      expect(await store.popUndo(), 'new');
      expect(await store.popUndo(), 'mid');
      expect(await store.popUndo(), isNull);

      store.undoDepth = 0; // disable undo entirely
      await store.pushUndo('gone');
      expect(await store.undoCount, 0);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('Service_BindsOptionsUndoDepth_ToTheStore', () {
    final store = MemoryGanjoorStore();
    GanjoorService(
      store: store,
      clock: clock,
      options: const GanjoorOptions(undoDepth: 7),
    );
    expect(store.undoDepth, 7);

    expect(
      () => GanjoorService(
        store: store,
        clock: clock,
        options: const GanjoorOptions(undoDepth: -5),
      ),
      throwsA(isA<GanjoorException>()),
    );
  });

  test('Import_PushesASnapshot_SoUndoRevertsTheImport', () async {
    final service = GanjoorService(
      store: MemoryGanjoorStore(),
      clock: clock,
      options: const GanjoorOptions(),
    );
    await service.addAccount('Bank', 'USD', '100');

    final snapshot = await service.exportJson();
    await service.addAccount('Wreck', 'USD', '999');
    expect(await service.accounts(), hasLength(2));

    await service.pushUndoSnapshot();
    await service.importJson(snapshot);

    expect(await service.accounts(), hasLength(1));
    expect(await service.undo(), isTrue);
    expect(await service.accounts(), hasLength(2)); // back to the wrecked state
  });

  test('Snapshot stacks are LIFO across several commands', () async {
    final service = GanjoorService(
      store: MemoryGanjoorStore(),
      clock: clock,
      options: const GanjoorOptions(),
    );
    final id = (await service.addAccount('Bank', 'USD', '100')).id;
    await service.record('$id', '30', 'food', false);
    await service.record('$id', '20', 'food', false);

    await service.undo(); // the second expense
    expect(await service.balance('Bank'), Money.parse('70'));
    await service.undo(); // the first expense
    expect(await service.balance('Bank'), Money.parse('100'));
    await service.undo(); // the account
    expect(await service.accounts(), isEmpty);
    expect(await service.undo(), isFalse);
  });

  test(
    'Undo restores ids, and a redo is just the same command again',
    () async {
      final service = GanjoorService(
        store: MemoryGanjoorStore(),
        clock: clock,
        options: const GanjoorOptions(),
      );
      final id = (await service.addAccount('Bank')).id;
      await service.record('$id', '10', 'food', false);
      await service.undo();
      final again = await service.record('$id', '10', 'food', false);
      expect(again.id, 1);
      expect(await service.store.undoCount, 2);
    },
  );

  test('Export and import go through real files', () async {
    final directory = Directory.systemTemp.createTempSync('ganjoor-files');
    try {
      final path = '${directory.path}/wallet.json';
      final service = GanjoorService(
        store: MemoryGanjoorStore(),
        clock: clock,
        options: const GanjoorOptions(),
      );
      await service.addAccount('Bank', 'USD', '10');
      await service.exportToFile(path);
      expect(File(path).existsSync(), isTrue);

      final fresh = GanjoorService(
        store: MemoryGanjoorStore(),
        clock: clock,
        options: const GanjoorOptions(),
      );
      await fresh.importFromFile(path);
      expect((await fresh.accounts()).single.name, 'Bank');
      // The import left a snapshot behind, so it can be reverted.
      expect(await fresh.undo(), isTrue);
      expect(await fresh.accounts(), isEmpty);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('CSV export writes what CSV import reads back', () async {
    final directory = Directory.systemTemp.createTempSync('ganjoor-csv-out');
    try {
      final path = '${directory.path}/ledger.csv';
      final service = GanjoorService(
        store: MemoryGanjoorStore(),
        clock: clock,
        options: const GanjoorOptions(),
      );
      final id = (await service.addAccount('Bank', 'USD', '100')).id;
      await service.record('$id', '10', 'food', false, notes: 'soup');
      await service.record('$id', '50', 'salary', true);

      expect(await service.exportCsv(path), 2);
      final text = File(path).readAsStringSync();
      expect(text, startsWith('Date,Description,Amount\n'));
      expect(text, contains('2026-09-19,soup,-10.00'));
      expect(text, contains('2026-09-19,salary,50.00'));

      final round = GanjoorService(
        store: MemoryGanjoorStore(),
        clock: clock,
        options: const GanjoorOptions(),
      );
      final target = (await round.addAccount('Bank')).id;
      final result = await round.importCsv(
        path,
        '$target',
        'imported',
        hasHeader: true,
        maxRows: 100,
      );
      expect(result.imported, 2);
      expect(result.skipped, 0);
      expect(await round.balance('Bank'), Money.parse('40'));
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}
