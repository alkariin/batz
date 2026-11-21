import 'dart:convert';

import 'package:batz/data/secret_store.dart';
import 'package:batz/data/server/certificate.dart';
import 'package:batz/data/server/server_client.dart';
import 'package:batz/data/server/server_repository.dart';
import 'package:batz/data/sync/sync_engine.dart';
import 'package:batz/data/sync/sync_store.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/pages/sync/sync_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_server.dart';
import '../../support/journal_harness.dart';

const me = '11111111-0000-4000-8000-000000000000';
const other = '22222222-0000-4000-8000-000000000000';

final pairing = Pairing(
  address: Uri.parse('https://192.168.1.95:8443'),
  deviceId: 'paired-id',
  deviceKey: 'key',
  fingerprint: 'AB:CD',
);

Future<void> wait(int millis) => Future<void>.delayed(Duration(milliseconds: millis));

void main() {
  late Harness device, server;
  late FakeServer fake;
  late MemorySecretStore secrets;
  late int reloads;

  setUp(() async {
    device = await Harness.open(deviceId: me);
    server = await Harness.open(deviceId: other);
    fake = FakeServer(server.journal);
    secrets = MemorySecretStore()..values[pairingSecretKey] = jsonEncode(pairing.toJson());
    reloads = 0;
    await device.journal.write(Modification.set('note', 'mine', {'title': 'Loyer', 'amount': -150000}));
    await device.journal.write(Modification.set('note', 'mine', {'done': true}));
  });
  tearDown(() async {
    await device.close();
    await server.close();
  });

  SyncCubit cubit({int debounce = 3000, int period = 300000, Future<void> Function()? onReceived}) {
    final c = SyncCubit(
      server: ServerRepository(secrets),
      journal: device.journal,
      engine: SyncEngine(device.journal, SyncStore(device.db)),
      store: SyncStore(device.db),
      transport: (_) => fake,
      onReceived: onReceived ?? () async => reloads++,
      debounce: Duration(milliseconds: debounce),
      period: Duration(milliseconds: period),
    );
    addTearDown(c.close);
    return c;
  }

  test('not paired: the data stay here, nothing is exchanged', () async {
    secrets.values.clear();
    final c = cubit();
    await c.start();
    expect(c.state.status, SyncStatus.notPaired);
    expect(fake.healthCalls, 0);
  });

  test('at start it exchanges: status, date, nothing pending, and the screens reload when entries arrive', () async {
    final c = cubit();
    final states = <SyncStatus>[];
    c.stream.listen((s) => states.add(s.status));
    await c.start();
    await wait(0); // the stream delivers the last state asynchronously
    expect(states, containsAllInOrder([SyncStatus.neverSynced, SyncStatus.syncing, SyncStatus.upToDate]));
    expect(c.state.lastSync, isNotNull);
    expect(c.state.pending, 0);
    expect(reloads, 0, reason: 'nothing received');

    // Another device's modification reaches the server.
    await server.journal.merge([entry(DateTime.now().millisecondsSinceEpoch, 0, other, 'theirs', 'title', 'Coop')]);
    await c.sync(manual: true);
    expect(reloads, 1);
    expect((await device.notes()).keys, containsAll(['mine', 'theirs']));
  });

  test('a failure to reload the screens after an exchange is not a synchronisation error', () async {
    final observer = _ErrorRecorder();
    final previous = Bloc.observer;
    Bloc.observer = observer;
    addTearDown(() => Bloc.observer = previous);
    final errors = observer.errors;
    final c = cubit(onReceived: () async => throw StateError('reload failed'));
    await c.start();
    expect(c.state.status, SyncStatus.upToDate);
    // Another device's modification reaches the server; receiving it makes
    // the screens reload, which fails.
    await server.journal.merge([entry(DateTime.now().millisecondsSinceEpoch, 0, other, 'theirs', 'title', 'Coop')]);
    await c.sync(manual: true);
    expect(errors, [isA<StateError>()], reason: 'reported to the observers');
    expect(c.state.status, SyncStatus.upToDate);
    expect(c.state.error, isNull);
    expect(c.state.lastSync, isNotNull);
    expect((await device.notes()).keys, containsAll(['mine', 'theirs']));
  });

  test('a server out of reach gives the offline status, no error, and counts what waits', () async {
    fake.failNext = ServerUnreachableException('off');
    final c = cubit();
    await c.start();
    expect(c.state.status, SyncStatus.offline);
    expect(c.state.error, isNull);
    expect(c.state.lastSync, isNull);
    expect(c.state.pending, 2, reason: 'two modifications, never sent');

    await c.sync(manual: true);
    expect(c.state.status, SyncStatus.upToDate);
    expect(c.state.pending, 0);
  });

  test('one exchange at a time; a trigger during one runs another after it', () async {
    fake.delay = const Duration(milliseconds: 30);
    final c = cubit();
    await c.start();
    final before = fake.healthCalls;
    final runs = [c.sync(), c.sync(), c.sync()];
    await Future.wait(runs);
    await c.whenIdle();
    expect(fake.maxActive, 1);
    expect(fake.healthCalls - before, 2, reason: 'the running one, then one more');
  });

  test('a modification is sent a few seconds later', () async {
    final c = cubit(debounce: 50);
    await c.start();
    final before = fake.requests.length;
    // Shown at once, before the exchange that follows.
    final counted = c.stream.firstWhere((s) => s.pending == 1);
    final sent = c.stream.firstWhere((s) => s.status == SyncStatus.upToDate && s.pending == 0);
    await device.journal.write(Modification.set('note', 'mine', {'title': 'Loyer et charges'}));
    await counted.timeout(const Duration(seconds: 10));
    await sent.timeout(const Duration(seconds: 10));
    expect(fake.requests.length, greaterThan(before));
    expect((await server.notes())['mine']!['title'], 'Loyer et charges');
  });

  test('every period while the app is shown, never while it is hidden', () async {
    final c = cubit(period: 50);
    await c.start();
    final started = fake.healthCalls;
    for (var i = 0; i < 100 && fake.healthCalls < started + 3; i++) {
      await wait(20);
    }
    expect(fake.healthCalls, greaterThanOrEqualTo(started + 3), reason: 'exchanges keep coming while shown');

    c.paused();
    // An exchange triggered while shown may still finish.
    await c.whenIdle();
    final hidden = fake.healthCalls;
    await wait(300);
    expect(fake.healthCalls, hidden, reason: 'six periods without any exchange');

    await c.resumed();
    expect(fake.healthCalls, hidden + 1, reason: 'back to the foreground');
  });

  group('versions', () {
    test('a server requiring a newer app: refused, with the reason; automatic exchanges stop', () async {
      fake.healthAnswer = Health(version: 'v0.9.0', minAppVersion: '9.9.9', syncProtocol: 1);
      final c = cubit(debounce: 20);
      await c.start();
      expect(c.state.status, SyncStatus.incompatible);
      expect(c.state.incompatibility, Incompatibility.appTooOld);
      expect(c.state.minAppVersion, '9.9.9');
      expect(fake.requests, isEmpty, reason: 'nothing exchanged');

      await device.journal.write(Modification.set('note', 'mine', {'title': 'x'}));
      await wait(100);
      expect(fake.healthCalls, 1, reason: 'no automatic retry');
      await c.sync(manual: true);
      expect(fake.healthCalls, 2, reason: 'the button retries');
    });

    test('a server too old for this app: refused, with its version', () async {
      fake.healthAnswer = Health(version: 'v0.2.0', minAppVersion: '0.1.0');
      final c = cubit();
      await c.start();
      expect(c.state.status, SyncStatus.incompatible);
      expect(c.state.incompatibility, Incompatibility.serverTooOld);
      expect(c.state.serverVersion, 'v0.2.0');
      expect(fake.requests, isEmpty);
    });

    test('a newer protocol on the server means this app is too old', () async {
      fake.healthAnswer = Health(version: 'v1.0.0', minAppVersion: '0.1.0', syncProtocol: 2);
      final c = cubit();
      await c.start();
      expect(c.state.incompatibility, Incompatibility.appTooOld);
    });
  });

  test('a revoked device stops exchanging; its data stay', () async {
    fake.failNext = ServerException(401, 'DEVICE_REVOKED', 'device is revoked');
    final notes = await device.notes();
    final c = cubit(debounce: 20);
    await c.start();
    expect(c.state.status, SyncStatus.revoked);
    expect(await device.notes(), notes);
    await device.journal.write(Modification.set('note', 'mine', {'title': 'offline still'}));
    await wait(100);
    expect(fake.healthCalls, 1, reason: 'no automatic retry');
  });

  test('a clock more than five minutes off the server is reported', () async {
    var offset = const Duration(minutes: 7);
    fake = FakeServer(server.journal, clock: () => DateTime.now().add(offset));
    final c = cubit();
    await c.start();
    expect(c.state.clockWarning, isTrue);
    expect(c.state.clockOffset!.inSeconds, closeTo(7 * 60, 2));
    expect(c.state.status, SyncStatus.upToDate, reason: 'it does not block');

    offset = const Duration(minutes: -2);
    await c.sync(manual: true);
    expect(c.state.clockWarning, isFalse);
  });

  test('any other failure is an error with its detail', () async {
    fake.failNext = ServerException(500, 'INTERNAL', 'internal error');
    final c = cubit();
    await c.start();
    expect(c.state.status, SyncStatus.error);
    expect(c.state.error, contains('INTERNAL'));
  });

  group('first exchange', () {
    setUp(() async => server.journal.write(Modification.set('note', 'theirs', {'title': 'Coop'})));

    test('unrelated data: the question; automatic exchanges wait for the answer', () async {
      final c = cubit(debounce: 20);
      await c.start();
      expect(c.state.status, SyncStatus.decisionNeeded);
      await device.journal.write(Modification.set('note', 'mine', {'title': 'x'}));
      await wait(100);
      expect(fake.healthCalls, 1);
      expect(fake.requests, hasLength(1), reason: 'only the first call, which learned the server state');
    });

    test('merge', () async {
      final c = cubit();
      await c.start();
      await c.merge();
      expect(c.state.status, SyncStatus.upToDate);
      expect((await device.notes()).keys, containsAll(['mine', 'theirs']));
      expect(reloads, 1);
    });

    test('replace, then the screens reload', () async {
      final c = cubit();
      await c.start();
      await c.replace();
      expect(c.state.status, SyncStatus.upToDate);
      expect((await device.notes()).keys, ['theirs']);
      expect(reloads, 1);
      expect(c.state.pending, 0);
    });
  });

  group('a server that changed (2.5)', () {
    for (final (name, error) in [
      ('another certificate', CertificateMismatchException('AB:CD', 'EF:01') as Object),
      ('an unknown device', ServerException(401, 'DEVICE_KEY_INVALID', 'device key is unknown')),
    ]) {
      test('$name: the server changed; automatic exchanges stop; a new pairing starts afresh', () async {
        fake.failNext = error;
        final notes = await device.notes();
        final c = cubit(debounce: 20);
        await c.start();
        expect(c.state.status, SyncStatus.serverChanged);
        expect(await device.notes(), notes);
        await device.journal.write(Modification.set('note', 'mine', {'title': 'still here'}));
        await wait(100);
        expect(fake.healthCalls, 1, reason: 'no automatic retry');

        // Paired again (here with the same fake): everything goes.
        await c.pairingChanged();
        expect(c.state.status, SyncStatus.upToDate);
        expect((await server.notes())['mine']!['title'], 'still here');
      });
    }
  });
}

/// Records the errors cubits report.
class _ErrorRecorder extends BlocObserver {
  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}
