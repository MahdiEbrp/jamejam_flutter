// Parity port of tests/JameJam.Tests/HaftKhan/Sync/SyncServiceTests.cs (10 cases),
// HaftKhan/Sync/SyncOptionsTests.cs (11 cases), and Sync/SyncSafetyTests.cs (8 cases).
//
// Device sync is where the app touches the outside world, so the three layers are tested
// together: the merge engine (uid identity, last-write-wins, dependency union, push safety,
// whole-merge undo), the transport policy (HTTPS/loopback rails), and the envelope
// (checksum, schema gate, size rail).
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/core/date_only.dart';
import 'package:jamejam/features/haftkhan/backup.dart';
import 'package:jamejam/features/haftkhan/haftkhan_service.dart';
import 'package:jamejam/features/haftkhan/models.dart';
import 'package:jamejam/features/haftkhan/task_repository.dart';
import 'package:jamejam/features/sync/sync_client.dart';
import 'package:jamejam/features/sync/sync_envelope.dart';
import 'package:jamejam/features/sync/sync_models.dart';
import 'package:jamejam/features/sync/sync_options.dart';

final now = DateTime.utc(2026, 9, 19, 10);
final earlier = now.subtract(const Duration(hours: 5));
final later = now.add(const Duration(hours: 5));

/// In-memory sync transport with scriptable remote state — the .NET suite's StubSyncClient.
class StubSyncClient implements SyncClient {
  StubSyncClient([BackupFile? remote])
    : remoteJson = remote == null ? null : Backup.toJson(remote);

  String? remoteJson;
  String? lastUpload;

  @override
  Future<String?> get() async => remoteJson;

  @override
  Future<void> put(String json) async {
    lastUpload = json;
    remoteJson = json; // the remote now holds what was pushed
  }
}

BackupFile remoteBackup(List<TaskDto> tasks) => BackupFile(
  version: Backup.currentVersion,
  exportedAt: '2026-09-19T00:00:00+00:00',
  tasks: tasks,
  dependencies: const [],
);

TaskDto remoteDto(int id, String title, String uid, DateTime updatedAt) =>
    TaskDto(
      id: id,
      title: title,
      notes: '',
      priority: 1,
      state: 0,
      dueDate: null,
      createdAt: updatedAt.toUtc().toIso8601String(),
      updatedAt: updatedAt.toUtc().toIso8601String(),
      completedAt: null,
      project: '',
      tags: const [],
      effort: 0,
      recurrence: 0,
      recurrenceInterval: 1,
      startedAt: null,
      uid: uid,
    );

void main() {
  late MemoryTaskRepository repository;
  late HaftKhanService service;

  setUp(() {
    repository = MemoryTaskRepository();
    service = HaftKhanService(repository: repository, clock: () => now);
  });

  Future<HaftKhanTask> makeLocal(
    String title,
    String uid,
    DateTime updatedAt, {
    TaskState state = TaskState.todo,
  }) async {
    final added = await repository.add(NewTask(title: title, uid: uid));
    final updated = added.copyWith(
      state: state,
      updatedAt: updatedAt,
      completedAt: state == TaskState.done ? updatedAt : null,
    );
    await repository.update(updated);
    return updated;
  }

  group('sync service parity', () {
    // FirstSync_IntoEmptyLocal_PullsRemote_AndPushesBack
    test(
      'the first sync pulls the remote and pushes the merged result back',
      () async {
        final client = StubSyncClient(
          remoteBackup([remoteDto(1, 'from remote', 'uid-a', earlier)]),
        );
        await service.addTask(title: 'local only');

        final report = await service.sync(client);

        expect(report.mode, SyncMode.merge);
        expect(report.pulled, 1);
        expect(report.pushed, 2);
        expect(report.total, 2);
        expect(
          (await repository.listAll())
              .firstWhere((task) => task.uid != 'uid-a')
              .title,
          'local only',
        );
        final pulled = (await repository.findByUid('uid-a'))!;
        expect(pulled.title, 'from remote');
        expect(pulled.updatedAt, earlier); // remote timestamps preserved
      },
    );

    // Merge_LastWriteWins_RemoteNewerUpdatesLocal
    test('a newer remote record wins', () async {
      await makeLocal('local version', 'uid-a', earlier);
      final client = StubSyncClient(
        remoteBackup([remoteDto(9, 'remote version', 'uid-a', later)]),
      );

      final report = await service.sync(client);

      expect(report.pulled, 1);
      expect((await repository.findByUid('uid-a'))!.title, 'remote version');
    });

    // Merge_LocalNewerWins_RemoteSkipped
    test('a newer local record is kept', () async {
      await makeLocal('local version', 'uid-a', later);
      final client = StubSyncClient(
        remoteBackup([remoteDto(9, 'remote version', 'uid-a', earlier)]),
      );

      final report = await service.sync(client);

      expect(report.pulled, 0);
      expect((await repository.findByUid('uid-a'))!.title, 'local version');
    });

    // Merge_TieKeepsLocal
    test('a tie keeps the local record', () async {
      await makeLocal('local version', 'uid-a', now);
      final client = StubSyncClient(
        remoteBackup([remoteDto(9, 'remote version', 'uid-a', now)]),
      );

      await service.sync(client);

      expect((await repository.findByUid('uid-a'))!.title, 'local version');
    });

    // Merge_UnionsDependencies_ByUid
    test('dependency edges are unioned by uid', () async {
      // Local: a ← b (b blocked by a). Remote: a ← c.
      final a = await repository.add(NewTask(title: 'a', uid: 'uid-a'));
      final b = await repository.add(NewTask(title: 'b', uid: 'uid-b'));
      await repository.addDependency(b.id, a.id);
      final client = StubSyncClient(
        BackupFile(
          version: Backup.currentVersion,
          exportedAt: '2026-09-19T00:00:00+00:00',
          tasks: [
            remoteDto(1, 'a', 'uid-a', earlier),
            remoteDto(3, 'c', 'uid-c', earlier),
          ],
          dependencies: const [
            DependencyDto(
              taskId: 3,
              dependsOnId: 1,
              taskUid: 'uid-c',
              dependsOnUid: 'uid-a',
            ),
          ],
        ),
      );

      await service.sync(client);

      final links = await repository.listDependencies();
      expect(links, hasLength(2)); // uid-b→uid-a preserved + uid-c→uid-a added

      final pairs = <String>[];
      for (final link in links) {
        final blocked = await repository.find(link.taskId);
        final blocker = await repository.find(link.dependsOnId);
        pairs.add('${blocked!.uid}->${blocker!.uid}');
      }
      expect(pairs, containsAll(['uid-b->uid-a', 'uid-c->uid-a']));
    });

    // Sync_IsUndoable
    test('a whole merge is undoable in one step', () async {
      await makeLocal('local', 'uid-a', earlier);
      final client = StubSyncClient(
        remoteBackup([remoteDto(1, 'remote', 'uid-b', earlier)]),
      );

      await service.sync(client);
      expect(await repository.listAll(), hasLength(2));

      await service.undo();

      final tasks = await repository.listAll();
      expect(tasks, hasLength(1));
      expect(tasks.first.title, 'local');
    });

    // Push_WithNonEmptyRemote_RequiresForce
    test('pushing over a non-empty remote needs confirmation', () async {
      await makeLocal('local', 'uid-a', now);
      final client = StubSyncClient(
        remoteBackup([remoteDto(1, 'remote', 'uid-z', earlier)]),
      );

      await expectLater(
        service.sync(client, mode: SyncMode.push),
        throwsA(
          isA<SyncException>().having(
            (error) => error.message,
            'message',
            contains('Confirm to overwrite'),
          ),
        ),
      );

      final report = await service.sync(
        client,
        mode: SyncMode.push,
        force: true,
      );
      expect(report.pushed, 1);
      expect(client.lastUpload, isNotNull);
    });

    // Pull_DoesNotPush
    test('pull never touches the remote', () async {
      final client = StubSyncClient(
        remoteBackup([remoteDto(1, 'remote', 'uid-a', earlier)]),
      );

      final report = await service.sync(client, mode: SyncMode.pull);

      expect(report.pushed, 0);
      expect(client.lastUpload, isNull);
    });

    // EmptyRemote_FullSync_ConvergesBothWays
    test('a missing remote document is created by the first sync', () async {
      await makeLocal('local', 'uid-a', now);
      final client = StubSyncClient(); // GET → null (404)

      final report = await service.sync(client);

      expect(report.pulled, 0);
      expect(report.pushed, 1);
      expect(client.lastUpload, isNotNull);
    });

    // Import_PreservesUids_AndLinksByUid
    test('import preserves uids and links by uid', () async {
      final backup = BackupFile(
        version: Backup.currentVersion,
        exportedAt: '2026-09-19T00:00:00+00:00',
        tasks: [
          remoteDto(1, 'first', 'uid-a', earlier),
          remoteDto(2, 'second', 'uid-b', earlier),
        ],
        dependencies: const [
          DependencyDto(
            taskId: 2,
            dependsOnId: 1,
            taskUid: 'uid-b',
            dependsOnUid: 'uid-a',
          ),
        ],
      );

      final result = await service.importBackup(backup, replace: false);

      expect(result.tasks, 2);
      expect(result.links, 1);
      expect(
        (await repository.listAll())
            .firstWhere((task) => task.title == 'first')
            .uid,
        'uid-a',
      );
      final link = (await repository.listDependencies()).single;
      expect((await repository.find(link.taskId))!.uid, 'uid-b');
      expect((await repository.find(link.dependsOnId))!.uid, 'uid-a');
    });

    // Sync_InvalidRemotePayload_FailsFriendly
    test('an unreadable remote fails with a friendly message', () async {
      final client = StubSyncClient()..remoteJson = '{"hello":true}';

      await expectLater(
        service.sync(client),
        throwsA(
          isA<SyncException>().having(
            (error) => error.message,
            'message',
            contains('did not return a valid Haft Khan backup'),
          ),
        ),
      );
    });

    // The transport is described by its client contract: a whole round trip over an
    // in-memory remote should leave both sides identical.
    test('merging twice is idempotent', () async {
      await service.addTask(title: 'a');
      final client = StubSyncClient();

      await service.sync(client);
      final first = Backup.fromJson(client.remoteJson!);
      await service.sync(client);
      final second = Backup.fromJson(client.remoteJson!);

      expect(
        second.tasks.map((task) => (task.id, task.title, task.uid, task.state)),
        first.tasks.map((task) => (task.id, task.title, task.uid, task.state)),
      );
      expect(second.dependencies.length, first.dependencies.length);
    });
  });

  group('sync options parity', () {
    // ValidOptions_Pass
    test('a valid HTTPS endpoint passes', () {
      expect(
        const SyncOptions(
          endpoint: 'https://sync.example.com/todos.json',
        ).validate,
        returnsNormally,
      );
    });

    // LoopbackHttp_IsAllowed
    test('plain HTTP on loopback is allowed', () {
      expect(
        const SyncOptions(
          endpoint: 'http://127.0.0.1:8080/todos.json',
        ).validate,
        returnsNormally,
      );
      expect(
        const SyncOptions(
          endpoint: 'http://localhost:8080/todos.json',
        ).validate,
        returnsNormally,
      );
    });

    // EmptyEndpoint_Throws
    test('an empty endpoint is refused', () {
      for (final endpoint in ['', '   ']) {
        expect(
          () => SyncOptions(endpoint: endpoint).validate(),
          throwsA(isA<SyncException>()),
        );
      }
    });

    // InsecureOrInvalidEndpoint_Throws
    test('insecure or invalid endpoints are refused', () {
      for (final endpoint in [
        'http://api.example.com/todos.json',
        'ftp://sync.example.com',
        'not-a-url',
      ]) {
        expect(
          () => SyncOptions(endpoint: endpoint).validate(),
          throwsA(isA<SyncException>()),
          reason: endpoint,
        );
      }
    });

    // EmptyToken_Throws
    test('an empty bearer token is refused', () {
      expect(
        () => const SyncOptions(
          endpoint: 'https://x.test',
          bearerToken: '',
        ).validate(),
        throwsA(
          isA<SyncException>().having(
            (error) => error.message,
            'message',
            contains('Bearer token'),
          ),
        ),
      );
    });

    // ZeroTimeout_Throws
    test('a zero timeout is refused', () {
      expect(
        () => const SyncOptions(
          endpoint: 'https://x.test',
          requestTimeout: Duration.zero,
        ).validate(),
        throwsA(isA<SyncException>()),
      );
    });

    // TooManyRetries_Throws
    test('too many retries are refused', () {
      expect(
        () => const SyncOptions(
          endpoint: 'https://x.test',
          maxRetries: 11,
        ).validate(),
        throwsA(isA<SyncException>()),
      );
    });

    // OversizedResponseCap_Throws
    test('an oversized response cap is refused', () {
      expect(
        () => const SyncOptions(
          endpoint: 'https://x.test',
          maxResponseBytes: SyncDefaults.maxResponseBytesBound + 1,
        ).validate(),
        throwsA(isA<SyncException>()),
      );
    });
  });

  group('sync envelope parity', () {
    const payload = '{"hello":["world",1,2]}';

    // SealOpen_RoundTrips_ThePayload
    test('sealing then opening round-trips the payload', () {
      final envelopeNow = DateTime.utc(2026, 9, 20, 12);
      final envelope = SyncSafety.seal(
        service: 'divan',
        payload: payload,
        deviceId: 'device-a',
        deviceName: 'laptop',
        now: envelopeNow,
      );

      final opened = SyncSafety.open(envelope.toJson());

      expect(opened.service, 'divan');
      expect(opened.deviceId, 'device-a');
      expect(opened.deviceName, 'laptop');
      expect(DateTime.parse(opened.createdAt).toUtc(), envelopeNow);
      expect(opened.payload, payload);
      expect(opened.schema, SyncEnvelope.currentSchema);
    });

    // Checksum_IsStableSha256Hex
    test('the checksum is stable lowercase SHA-256 hex', () {
      expect(
        SyncSafety.checksumOf('hello'),
        '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
      );
    });

    // Open_CorruptedPayload_FailsWithIntegrityError
    test('a tampered payload fails the integrity check', () {
      final sealed = SyncSafety.seal(
        service: 'divan',
        payload: payload,
        deviceId: 'a',
        deviceName: 'laptop',
        now: now,
      );
      final tampered = SyncEnvelope(
        schema: sealed.schema,
        service: sealed.service,
        deviceId: sealed.deviceId,
        deviceName: sealed.deviceName,
        createdAt: sealed.createdAt,
        payload: '{"hello":"tampered"}',
        checksum: sealed.checksum,
      );

      expect(
        () => SyncSafety.open(tampered.toJson()),
        throwsA(
          isA<SyncException>()
              .having(
                (error) => error.message,
                'message',
                contains('integrity check'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('Nothing was merged'),
              ),
        ),
      );
    });

    // Open_WrongSchema_FailsWithUpgradeHint
    test('an unknown protocol version asks for an upgrade', () {
      final sealed = SyncSafety.seal(
        service: 'divan',
        payload: payload,
        deviceId: 'a',
        deviceName: 'laptop',
        now: now,
      );
      final older = SyncEnvelope(
        schema: 'jamejam.sync/0',
        service: sealed.service,
        deviceId: sealed.deviceId,
        deviceName: sealed.deviceName,
        createdAt: sealed.createdAt,
        payload: sealed.payload,
        checksum: sealed.checksum,
      );

      expect(
        () => SyncSafety.open(older.toJson()),
        throwsA(
          isA<SyncException>().having(
            (error) => error.message.toLowerCase(),
            'message',
            contains('upgrade'),
          ),
        ),
      );
    });

    // Open_GarbageDocument_FailsFriendly
    test('garbage documents fail with a sync error, not a crash', () {
      for (final document in ['{"hello":true}', 'not json at all', '']) {
        expect(
          () => SyncSafety.open(document),
          throwsA(isA<SyncException>()),
          reason: document,
        );
      }
    });

    // Seal_OversizePayload_FailsBeforeAnyWire
    test('an oversize payload is refused before it reaches the wire', () {
      expect(
        () => SyncSafety.seal(
          service: 'divan',
          payload: 'x' * 2048,
          deviceId: 'a',
          deviceName: 'n',
          now: now,
          maxPayloadBytes: 1024,
        ),
        throwsA(
          isA<SyncException>().having(
            (error) => error.message,
            'message',
            contains('above the configured maximum'),
          ),
        ),
      );
    });

    // Seal_RejectsEmptyEssentials
    test('sealing refuses empty service, payload and device id', () {
      expect(
        () => SyncSafety.seal(
          service: '',
          payload: payload,
          deviceId: 'a',
          deviceName: 'n',
          now: now,
        ),
        throwsA(isA<SyncException>()),
      );
      expect(
        () => SyncSafety.seal(
          service: 'divan',
          payload: '   ',
          deviceId: 'a',
          deviceName: 'n',
          now: now,
        ),
        throwsA(isA<SyncException>()),
      );
      expect(
        () => SyncSafety.seal(
          service: 'divan',
          payload: payload,
          deviceId: ' ',
          deviceName: 'n',
          now: now,
        ),
        throwsA(isA<SyncException>()),
      );
    });

    // Open_HandWrittenLowercaseEnvelope_Works
    test('a hand-written envelope with lowercase keys opens too', () {
      final sealed = SyncSafety.seal(
        service: 'divan',
        payload: payload,
        deviceId: 'a',
        deviceName: 'n',
        now: now,
      );
      final handwritten =
          '{"schema":"jamejam.sync/1",'
          '"service":"divan",'
          '"deviceid":"a",'
          '"devicename":"n",'
          '"createdat":"${sealed.createdAt}",'
          '"payload":"{\\"hello\\":[\\"world\\",1,2]}",'
          '"checksum":"${sealed.checksum}"}';

      expect(SyncSafety.open(handwritten).payload, payload);
    });
  });

  group('memory sync client', () {
    test('the in-memory client stores one document and counts calls', () async {
      final client = MemorySyncClient();

      expect(await client.get(), isNull);
      await client.put('{"a":1}');
      expect(await client.get(), '{"a":1}');
      expect(client.putCount, 1);
      expect(client.getCount, 2);
    });
  });

  group('DateOnly storage form', () {
    test('ISO dates round-trip', () {
      expect(DateOnly.parseIso('2026-09-19').toIso(), '2026-09-19');
    });
  });
}
