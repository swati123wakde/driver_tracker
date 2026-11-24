import 'dart:async';

import 'package:driver_tracker/data/local/in_memory_location_store.dart';
import 'package:driver_tracker/services/retry_policy.dart';
import 'package:driver_tracker/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  late InMemoryLocationStore store;
  late FakeLocationApi api;
  late FakeConnectivity connectivity;
  late DateTime now;
  late SyncService service;

  SyncService build({int batchSize = 25}) => SyncService(
        store: store,
        api: api,
        connectivity: connectivity,
        retryPolicy: const RetryPolicy(jitter: 0), // deterministic backoff
        batchSize: batchSize,
        insertDebounce: Duration.zero,
        autoRetry: false, // tests drive retries explicitly via the clock
        clock: () => now,
      );

  Future<void> seed(int count) async {
    for (var i = 0; i < count; i++) {
      await store.insert(record('r$i', now.add(Duration(seconds: i))));
    }
  }

  setUp(() {
    store = InMemoryLocationStore();
    api = FakeLocationApi();
    connectivity = FakeConnectivity(online: false);
    now = DateTime(2026, 1, 1, 9);
    service = build();
  });

  tearDown(() => service.dispose());

  group('offline storage', () {
    test('records stay pending locally and nothing is sent while offline',
        () async {
      await seed(3);

      final report = await service.sync();

      expect(report.skippedOffline, isTrue);
      expect(api.requests, isEmpty);
      final stats = await store.stats();
      expect(stats.pending, 3);
      expect(stats.synced, 0);
    });

    test('pending records upload automatically when connectivity returns',
        () async {
      await seed(3);
      service.start(); // offline: initial sync is a no-op
      await settle();
      expect(api.requests, isEmpty);

      connectivity.setOnline(true);
      await settle();

      expect(api.server.keys, containsAll(['r0', 'r1', 'r2']));
      expect((await store.stats()).synced, 3);
    });

    test('large backlogs are drained in batches', () async {
      service = build(batchSize: 2);
      connectivity.setOnline(true);
      await seed(5);

      final report = await service.sync();

      expect(report.uploaded, 5);
      expect(api.requests.map((r) => r.length), [2, 2, 1]);
    });
  });

  group('duplicate prevention', () {
    test('overlapping sync calls never upload a record twice', () async {
      connectivity.setOnline(true);
      await seed(4);
      api.gate = Completer<void>(); // hold the first request open

      final first = service.sync();
      final second = service.sync();
      final third = service.sync();
      await settle();
      api.gate!.complete();
      await Future.wait([first, second, third]);

      expect(api.requests, hasLength(1));
      expect(api.sendCounts.values, everyElement(1));
      expect(api.server, hasLength(4));
    });

    test('a lost acknowledgement is retried without creating duplicates',
        () async {
      connectivity.setOnline(true);
      await seed(2);
      api.script.add(ApiBehavior.lostAck); // server stores, client sees error

      final failed = await service.sync();
      expect(failed.failed, 2);
      expect((await store.stats()).synced, 0);

      now = now.add(const Duration(seconds: 3)); // past the 2s backoff
      final retried = await service.sync();

      expect(retried.uploaded, 2);
      expect(api.server, hasLength(2), reason: 'server keeps one copy');
      expect(api.duplicatesIgnored, 2);
      expect((await store.stats()).synced, 2);
    });
  });

  group('retry handling', () {
    test('failed records back off, then succeed once due', () async {
      connectivity.setOnline(true);
      await seed(2);
      api.script.add(ApiBehavior.fail);

      final report = await service.sync();
      expect(report.failed, 2);
      expect(report.error, contains('503'));

      final r0 = store.byId('r0')!;
      expect(r0.attempts, 1);
      expect(r0.nextAttemptAt, now.add(const Duration(seconds: 2)));
      expect((await store.stats()).retrying, 2);

      // Not due yet: nothing is re-sent.
      await service.sync();
      expect(api.requests, hasLength(1));

      now = now.add(const Duration(seconds: 2));
      final retry = await service.sync();

      expect(retry.uploaded, 2);
      expect(api.requests, hasLength(2));
      final stats = await store.stats();
      expect(stats.synced, 2);
      expect(stats.retrying, 0);
      expect(store.byId('r0')!.lastError, isNull);
    });

    test('consecutive failures grow the backoff', () async {
      connectivity.setOnline(true);
      await seed(1);
      api.script.addAll([ApiBehavior.fail, ApiBehavior.fail]);

      await service.sync();
      now = now.add(const Duration(seconds: 2));
      await service.sync();

      final r = store.byId('r0')!;
      expect(r.attempts, 2);
      expect(r.nextAttemptAt, now.add(const Duration(seconds: 4)));
    });

    test('manual sync ignores backoff', () async {
      connectivity.setOnline(true);
      await seed(1);
      api.script.add(ApiBehavior.fail);
      await service.sync();

      final report = await service.sync(ignoreBackoff: true);

      expect(report.uploaded, 1);
    });
  });

  group('RetryPolicy', () {
    test('doubles each attempt and is capped', () {
      const policy = RetryPolicy(
        baseDelay: Duration(seconds: 2),
        maxDelay: Duration(seconds: 30),
        jitter: 0,
      );
      expect(
        [1, 2, 3, 4, 5, 6, 50].map((a) => policy.delayFor(a).inSeconds),
        [2, 4, 8, 16, 30, 30, 30],
      );
    });
  });
}
