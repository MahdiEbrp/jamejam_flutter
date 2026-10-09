// Parity port of tests/JameJam.Tests/Divan/DivanSyncTests.cs and DivanSyncEdgeTests.cs —
// the adapter's capture/merge/apply matrix, the SQLite v1→v2 migration, and the generic
// sync engine over an in-memory "any server" blob client.
//
// One recorded divergence: .NET writes timestamps as `2026-09-20T13:00:00.0000000+00:00`
// while Dart's `toIso8601String()` writes `2026-09-20T13:00:00.000Z`. Both round-trip to the
// same instant and both devices emit the same bytes, so the assertions compare instants and
// byte-identical captures instead of the literal spelling.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/sqlite_database.dart';
import 'package:jamejam/features/divan/divan_defaults.dart';
import 'package:jamejam/features/divan/divan_service.dart';
import 'package:jamejam/features/divan/divan_store.dart';
import 'package:jamejam/features/divan/divan_sync_adapter.dart';
import 'package:jamejam/features/divan/models.dart';
import 'package:jamejam/features/divan/sqlite_divan_store.dart';
import 'package:jamejam/features/sync/sync_client.dart';
import 'package:jamejam/features/sync/sync_envelope.dart';
import 'package:jamejam/features/sync/sync_models.dart';

/// A shared JSON document — the smallest server any host can implement.
class BlobClient implements SyncClient {
  String? document;

  @override
  Future<String?> get() async => document;

  @override
  Future<void> put(String json) async => document = json;
}

void main() {
  final clock = DateTime.utc(2026, 9, 20, 12);
  const stamp = '2026-09-20T11:00:00.0000000+00:00';

  ({DivanService service, MemoryDivanStore store}) pad([DateTime? now]) {
    final store = MemoryDivanStore();
    return (
      service: DivanService(store: store, clock: () => now ?? clock),
      store: store,
    );
  }

  DivanSyncAdapter adapterFor(DivanService service, DivanStore store) =>
      DivanSyncAdapter(service: service, store: store, clock: () => clock);

  String notesPayload(String title) => jsonEncode({
    'notebooks': <Object?>[],
    'notes': [
      {
        'syncId': '11111111-1111-7111-8111-111111111111',
        'notebook': 'N',
        'title': title,
        'body': 'x',
        'tags': '',
        'pinned': false,
        'archived': false,
        'createdAt': stamp,
        'updatedAt': stamp,
      },
    ],
    'tombstones': <Object?>[],
  });

  group('DivanSyncAdapter — capture and apply', () {
    test('apply aligns notebook timestamps so devices converge', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);
      final payload = jsonEncode({
        'notebooks': [
          {'name': 'Shared', 'archived': false, 'updatedAt': stamp},
        ],
        'notes': <Object?>[],
        'tombstones': <Object?>[],
      });

      await adapter.apply(payload);
      expect(
        (await p.store.findNotebookByName('Shared'))!.updatedAt,
        DateTime.parse(stamp).toUtc(),
      );

      // Re-capturing must carry exactly that instant — no device-local drift.
      final captured = await adapter.capture();
      final capturedAt =
          (jsonDecode(captured) as Map<String, dynamic>)['notebooks'] as List;
      expect(
        DateTime.parse(
          ((capturedAt.single as Map)['updatedAt'] as String),
        ).toUtc(),
        DateTime.parse(stamp).toUtc(),
      );
    });

    test('a note gets a sync id, and stores assign one', () async {
      final p = pad();
      final note = await p.service.addNote('Alpha', 'body');
      expect(note.syncId, isNotEmpty);
      expect((await p.store.findNote(note.id))!.syncId, isNotEmpty);

      // Plain store adds get identities too (the import path).
      final direct = await p.store.addNote(
        Note(
          notebookId: 1,
          title: 'Beta',
          body: 'b',
          createdAt: clock,
          updatedAt: clock,
        ),
      );
      expect(direct.syncId, isNotEmpty);
    });

    test('delete records a tombstone and undo retracts it', () async {
      final p = pad();
      final note = await p.service.addNote('Doomed', 'body');
      final syncId = note.syncId;

      await p.service.delete(note.id);
      final tombstones = await p.store.getTombstones();
      expect(tombstones, hasLength(1));
      expect(tombstones.single.syncId, syncId);

      expect(await p.service.undo(), isTrue);
      expect(await p.store.getTombstones(), isEmpty);
      expect((await p.service.getNote(note.id))!.syncId, syncId);
    });

    test('apply pushes exactly one undo snapshot', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);
      final payload = jsonEncode({
        'notebooks': [
          {'name': 'Synced', 'archived': false, 'updatedAt': stamp},
        ],
        'notes': <Object?>[],
        'tombstones': <Object?>[],
      });

      final before = await p.store.undoCount;
      expect(await adapter.apply(payload), 1);
      expect(await p.store.undoCount, before + 1);

      expect(await p.service.undo(), isTrue);
      expect(await p.store.findNotebookByName('Synced'), isNull);
    });

    test(
      'apply aligns an archive flag and a title in place, idempotently',
      () async {
        final p = pad();
        final adapter = adapterFor(p.service, p.store);
        await p.service.createNotebook('Research');
        final note = await p.service.addNote('Original', 'body');

        final payload = jsonEncode({
          'notebooks': [
            {'name': 'Research', 'archived': true, 'updatedAt': stamp},
          ],
          'notes': [
            {
              'syncId': note.syncId,
              'notebook': 'Research',
              'title': 'Renamed remotely',
              'body': 'body',
              'tags': '',
              'pinned': false,
              'archived': false,
              'createdAt': stamp,
              'updatedAt': stamp,
            },
          ],
          'tombstones': <Object?>[],
        });

        expect(await adapter.apply(payload), 2);
        expect(
          (await p.store.findNotebookByName('Research'))!.isArchived,
          isTrue,
        );

        final edited = (await p.service.getNote(note.id))!;
        expect(edited.title, 'Renamed remotely');
        expect(edited.id, note.id, reason: 'local id preserved');
        expect(edited.syncId, note.syncId);

        expect(
          await adapter.apply(payload),
          0,
          reason: 're-applying is a no-op',
        );
      },
    );

    test('a remote tombstone removes the local copy', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);
      final note = await p.service.addNote('Doomed remotely', 'body');

      final payload = jsonEncode({
        'notebooks': <Object?>[],
        'notes': <Object?>[],
        'tombstones': [
          {'syncId': note.syncId, 'deletedAt': stamp},
        ],
      });

      expect(await adapter.apply(payload), 1);
      expect(await p.service.getNote(note.id), isNull);
      expect(await p.store.getTombstones(), hasLength(1));
    });

    test('long notebook names are clipped to the rail on apply', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);
      final longName = 'x' * (DivanDefaults.maxNotebookNameLength + 40);
      final payload = jsonEncode({
        'notebooks': [
          {'name': longName, 'archived': false, 'updatedAt': stamp},
        ],
        'notes': <Object?>[],
        'tombstones': <Object?>[],
      });

      await adapter.apply(payload);
      expect(
        (await p.store.listNotebooks()).single.name.length,
        DivanDefaults.maxNotebookNameLength,
      );
    });

    test('empty notebook names are skipped', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);
      final payload = jsonEncode({
        'notebooks': [
          {'name': '   ', 'archived': false, 'updatedAt': stamp},
        ],
        'notes': <Object?>[],
        'tombstones': <Object?>[],
      });

      expect(await adapter.apply(payload), 0);
      expect(await p.store.listNotebooks(), isEmpty);
    });

    test(
      'capture falls back to created-at for notebooks without a timestamp',
      () async {
        final p = pad();
        await p.store.addNotebook(
          Notebook(id: 0, name: 'Legacy', createdAt: clock),
        );
        final adapter = adapterFor(p.service, p.store);

        final json = await adapter.capture();
        expect(json, contains('2026-09-20T12:00:00.000Z'));
      },
    );
  });

  group('DivanSyncAdapter — merge', () {
    test('a newer edit wins in both directions', () async {
      final a = pad();
      final b = pad();
      final adapterA = adapterFor(a.service, a.store);
      final adapterB = adapterFor(b.service, b.store);

      final seed = await a.service.addNote('Shared', 'v1');
      // Bob holds the same logical note only if the sync ids match — mint it the way the
      // .NET test does: create a normal note, then adopt Alice's identity.
      await b.service.addNote('Shared', 'v1');
      final bobNote = (await b.store.listNotes()).single;
      await b.store.updateNote(bobNote.copyWith(syncId: seed.syncId));
      await b.store.updateNote(
        (await b.store.findNote(bobNote.id))!.copyWith(
          body: 'v2 from bob',
          updatedAt: clock.add(const Duration(minutes: 1)),
        ),
      );

      final local = await adapterA.capture();
      final remote = await adapterB.capture();
      final merged = await adapterA.merge(local, remote, 'a', 'b');

      expect(await adapterA.apply(merged), 1);
      expect((await a.service.getNote(seed.id))!.body, 'v2 from bob');

      // The reverse direction converges to the same winner.
      final mergedBack = await adapterB.merge(remote, local, 'b', 'a');
      expect(await adapterB.apply(mergedBack), 0);
    });

    test(
      'a tombstone deletes the remote copy, a newer edit resurrects it',
      () async {
        final a = pad();
        final b = pad();
        final adapterA = adapterFor(a.service, a.store);
        final adapterB = adapterFor(b.service, b.store);

        final seed = await a.service.addNote('Ephemeral', 'body');
        final bobNote = await b.store.addNote(
          Note(
            notebookId: 1,
            title: 'Ephemeral',
            body: 'body',
            createdAt: clock,
            updatedAt: clock.subtract(const Duration(seconds: 5)),
            syncId: seed.syncId,
          ),
        );

        await a.service.delete(seed.id);
        final local = await adapterA.capture();
        final remote = await adapterB.capture();
        await adapterA.apply(await adapterA.merge(local, remote, 'a', 'b'));
        await adapterB.apply(await adapterB.merge(remote, local, 'b', 'a'));

        expect(await b.service.getNote(bobNote.id), isNull);
        expect(await a.service.list(), isEmpty);

        // A NEWER edit (a pre-delete snapshot resurrected elsewhere) beats the tombstone.
        await b.store.addNote(
          Note(
            notebookId: 1,
            title: 'Ephemeral',
            body: 'phoenix',
            createdAt: seed.createdAt,
            updatedAt: clock.add(const Duration(minutes: 2)),
            syncId: seed.syncId,
          ),
        );
        final remote2 = await adapterB.capture();
        final local2 = await adapterA.capture();
        await adapterA.apply(await adapterA.merge(local2, remote2, 'a', 'b'));

        expect((await a.service.list()).single.body, 'phoenix');
      },
    );

    test('an equal-age live note loses to the tombstone', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);
      final note = await p.service.addNote('Contested', 'body');

      final remote = jsonEncode({
        'notebooks': <Object?>[],
        'notes': <Object?>[],
        'tombstones': [
          {
            'syncId': note.syncId,
            'deletedAt': '2026-09-20T12:00:00.0000000+00:00',
          },
        ],
      });
      final local = await adapter.capture();
      final merged = await adapter.merge(local, remote, 'a', 'b');

      expect(merged, isNot(contains('Contested')));
      await adapter.apply(merged);
      expect(await p.service.getNote(note.id), isNull);
    });

    test(
      'notebooks union and the archive flag follows the latest write',
      () async {
        final a = pad();
        final adapterA = adapterFor(a.service, a.store);
        await a.service.createNotebook('Research');

        final later = clock.add(const Duration(minutes: 1));
        final b = pad(later);
        final adapterB = adapterFor(b.service, b.store);
        await b.service.createNotebook('Writing');
        await b.service.createNotebook('research');
        await b.service.archiveNotebook('research', true);

        final local = await adapterA.capture();
        final remote = await adapterB.capture();
        await adapterA.apply(await adapterA.merge(local, remote, 'a', 'b'));

        expect(await a.service.listNotebooks(), hasLength(2));
        expect(
          (await a.store.findNotebookByName('research'))!.name,
          'Research',
        );
        expect(
          (await a.store.findNotebookByName('Research'))!.isArchived,
          isTrue,
          reason: 'archived later on B',
        );
        expect(await a.store.findNotebookByName('Writing'), isNotNull);
      },
    );

    test('a newer unarchive beats an older archive', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);
      await p.service.createNotebook('N');

      final older = clock.subtract(const Duration(minutes: 5));
      final archived = jsonEncode({
        'notebooks': [
          {'name': 'N', 'archived': true, 'updatedAt': older.toIso8601String()},
        ],
        'notes': <Object?>[],
        'tombstones': <Object?>[],
      });
      final local = await adapter.capture();
      await adapter.apply(await adapter.merge(local, archived, 'a', 'b'));

      expect((await p.store.findNotebookByName('N'))!.isArchived, isFalse);
    });

    test(
      'both devices deleting the same note converge on one timestamp',
      () async {
        final a = pad();
        final b = pad();
        final adapterA = adapterFor(a.service, a.store);
        final adapterB = adapterFor(b.service, b.store);

        final seed = await a.service.addNote('Deleted everywhere', 'body');
        await b.store.addNote(
          Note(
            notebookId: 1,
            title: 'Deleted everywhere',
            body: 'body',
            createdAt: seed.createdAt,
            updatedAt: seed.updatedAt,
            syncId: seed.syncId,
          ),
        );

        await a.service.delete(seed.id);
        await b.service.delete((await b.store.listNotes()).single.id);

        final merged = await adapterA.merge(
          await adapterA.capture(),
          await adapterB.capture(),
          'a',
          'b',
        );
        await adapterA.apply(merged);
        await adapterB.apply(merged);

        expect(await adapterA.capture(), await adapterB.capture());
      },
    );

    test('merge is deterministic under an exact time tie', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);

      final ab = await adapter.merge(
        notesPayload('A-side'),
        notesPayload('B-side'),
        'a',
        'b',
      );
      final ba = await adapter.merge(
        notesPayload('B-side'),
        notesPayload('A-side'),
        'b',
        'a',
      );

      expect(ab, ba, reason: 'both devices resolve the tie to the same bytes');
      final winner = ab.contains('A-side') ? 'A-side' : 'B-side';
      final loser = winner == 'A-side' ? 'B-side' : 'A-side';
      expect(ab, contains(winner));
      expect(ab, isNot(contains(loser)));
    });

    test('a notebook tie with both archived stays archived', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);
      final payload = jsonEncode({
        'notebooks': [
          {'name': 'N', 'archived': true, 'updatedAt': stamp},
        ],
        'notes': <Object?>[],
        'tombstones': <Object?>[],
      });

      final merged = await adapter.merge(payload, payload, 'a', 'b');
      expect(merged, contains('"archived":true'));
    });

    test('a null payload yields an empty state', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);
      final merged = await adapter.merge(
        'null',
        '{"notebooks":[],"notes":[],"tombstones":[]}',
        'a',
        'b',
      );
      expect(merged, contains('notebooks'));
    });

    test('a garbage payload fails friendly', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);

      await expectLater(
        adapter.merge('{}', 'not json at all', 'a', 'b'),
        throwsA(
          isA<SyncException>().having(
            (error) => error.message,
            'message',
            contains('not valid'),
          ),
        ),
      );
    });
  });

  group('SyncEngine over the Divan adapter', () {
    test('two devices exchange notes', () async {
      final a = pad();
      final b = pad();
      final adapterA = adapterFor(a.service, a.store);
      final adapterB = adapterFor(b.service, b.store);
      await a.service.addNote('From Alice', 'hello');
      await b.service.addNote('From Bob', 'hi');

      final server = BlobClient();
      await SyncEngine.run(
        server,
        adapterA,
        deviceId: 'alice',
        deviceName: 'Alice',
        now: clock,
      );
      await SyncEngine.run(
        server,
        adapterB,
        deviceId: 'bob',
        deviceName: 'Bob',
        now: clock,
      );
      final run = await SyncEngine.run(
        server,
        adapterA,
        deviceId: 'alice',
        deviceName: 'Alice',
        now: clock,
      );

      expect(run.applied, 1);
      expect(
        (await a.service.list()).where((note) => note.title == 'From Bob'),
        hasLength(1),
      );
      expect(
        (await b.service.list()).where((note) => note.title == 'From Alice'),
        hasLength(1),
      );
      // Local ids stay local: Alice's own note kept id 1.
      expect((await a.service.getNote(1))!.title, 'From Alice');
    });

    test('the first sync seeds the remote and the second is a no-op', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);
      await p.service.addNote('Solo', 'body');

      final server = BlobClient();
      final first = await SyncEngine.run(
        server,
        adapter,
        deviceId: 'device-a',
        deviceName: 'testbox',
        now: clock,
      );
      expect(first.firstSync, isTrue);
      expect(first.pushed, isTrue);
      expect(first.describe(), contains('First sync'));
      expect(server.document, isNotNull);

      final second = await SyncEngine.run(
        server,
        adapter,
        deviceId: 'device-a',
        deviceName: 'testbox',
        now: clock,
      );
      expect(second.applied, 0);
      expect(second.pushed, isFalse);
      expect(second.describe(), contains('Merged: 0 record(s)'));
    });

    test(
      'pull never writes the remote, and an empty remote is a no-op',
      () async {
        final p = pad();
        final adapter = adapterFor(p.service, p.store);
        await p.service.addNote('Solo', 'body');

        final server = BlobClient();
        final run = await SyncEngine.run(
          server,
          adapter,
          deviceId: 'device-a',
          deviceName: 'testbox',
          mode: SyncMode.pull,
          now: clock,
        );

        expect(run.pushed, isFalse);
        expect(run.firstSync, isFalse);
        expect(server.document, isNull);
      },
    );

    test('push over a differing remote needs force', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);
      await p.service.addNote('Solo', 'body');

      final server = BlobClient()
        ..document = SyncSafety.seal(
          service: 'divan',
          payload: '{"notebooks":[],"notes":[],"tombstones":[]}',
          deviceId: 'other',
          deviceName: 'Other',
          now: clock,
        ).toJson();

      await expectLater(
        SyncEngine.run(
          server,
          adapter,
          deviceId: 'device-a',
          deviceName: 'testbox',
          mode: SyncMode.push,
        ),
        throwsA(
          isA<SyncException>().having(
            (error) => error.message,
            'message',
            allOf(contains('Other'), contains('overwrite')),
          ),
        ),
      );

      final forced = await SyncEngine.run(
        server,
        adapter,
        deviceId: 'device-a',
        deviceName: 'testbox',
        mode: SyncMode.push,
        force: true,
      );
      expect(forced.pushed, isTrue);
      expect(forced.describe(), contains('remote replaced'));
    });

    test('a foreign service on the URL fails', () async {
      final p = pad();
      final adapter = adapterFor(p.service, p.store);

      final server = BlobClient()
        ..document = SyncSafety.seal(
          service: 'haftkhan',
          payload: '{"tasks":[]}',
          deviceId: 'other',
          deviceName: 'Other',
          now: clock,
        ).toJson();

      await expectLater(
        SyncEngine.run(
          server,
          adapter,
          deviceId: 'device-a',
          deviceName: 'testbox',
        ),
        throwsA(
          isA<SyncException>().having(
            (error) => error.message,
            'message',
            contains("'divan' cannot merge"),
          ),
        ),
      );
    });
  });

  group('SQLite', () {
    test('a v1 database migrates to v2', () async {
      final directory = Directory.systemTemp.createTempSync('divan-migration');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });

      final path = '${directory.path}/divan.db';
      await _seedV1Database(path);

      final store = SqliteDivanStore(path);
      await store.initialize();

      final note = (await store.findNote(1))!;
      expect(
        note.syncId,
        isNotEmpty,
        reason: 'the migration backfilled identity',
      );
      expect(
        (await store.findNotebook(1))!.updatedAt,
        isNotNull,
        reason: 'and the notebook timestamp',
      );
      expect(await store.getTombstones(), isEmpty);

      // New writes work, including tombstones.
      final added = await store.addNote(
        Note(
          notebookId: 1,
          title: 'New',
          body: 'b',
          createdAt: clock,
          updatedAt: clock,
        ),
      );
      await store.removeNote(added.id, clock);
      expect(await store.getTombstones(), hasLength(1));
      await store.close();
    });
  });
}

/// Writes a genuine schema-v1 pad (pre-sync-identity) through the shared database seam —
/// the same hand-built fixture the .NET test creates with a raw connection.
Future<void> _seedV1Database(String path) async {
  final database = SqliteDatabase(path);
  await database.initialize([
    '''
CREATE TABLE notebooks (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
    created_at TEXT NOT NULL, is_archived INTEGER NOT NULL DEFAULT 0);
CREATE TABLE notes (id INTEGER PRIMARY KEY AUTOINCREMENT, notebook_id INTEGER NOT NULL,
    title TEXT NOT NULL, body TEXT NOT NULL, tags TEXT NOT NULL,
    pinned INTEGER NOT NULL DEFAULT 0, archived INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
CREATE TABLE undo_log (id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT NOT NULL,
    payload TEXT NOT NULL);
INSERT INTO notebooks (name, created_at, is_archived)
    VALUES ('Old', '2026-01-01T00:00:00.0000000+00:00', 0);
INSERT INTO notes (notebook_id, title, body, tags, pinned, archived, created_at, updated_at)
    VALUES (1, 'Legacy note', 'body', '', 0, 0,
            '2026-01-01T00:00:00.0000000+00:00', '2026-01-01T00:00:00.0000000+00:00');
PRAGMA user_version = 1;''',
  ]);
  await database.close();
}
