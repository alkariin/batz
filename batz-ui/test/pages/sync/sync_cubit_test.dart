import 'dart:convert';

import 'package:batz/data/secret_store.dart';
import 'package:batz/data/server/server_client.dart';
import 'package:batz/data/server/server_repository.dart';
import 'package:batz/data/sync/sync_engine.dart';
import 'package:batz/data/sync/sync_store.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/pages/sync/sync_cubit.dart';
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

  SyncCubit cubit({int debounce = 3000, int period = 300000}) {
    final c = SyncCubit(
      server: ServerRepository(secrets),
      journal: device.journal,
      engine: SyncEngine(device.journal, SyncStore(device.db)),
      store: SyncStore(device.db),
      transport: (_) => fake,
      onReceived: () async => reloads++,
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
    await server.journal.write(Modification.set('note', 'theirs', {'title': 'Coop'}));
    final c = cubit();
    final states = <SyncStatus>[];
    c.stream.listen((s) => states.add(s.status));
    await c.start();
    expect(states, containsAllInOrder([SyncStatus.neverSynced, SyncStatus.syncing, SyncStatus.upToDate]));
    expect(c.state.lastSync, isNotNull);
    expect(c.state.pending, 0);
    expect(reloads, 1);
    expect((await device.notes()).keys, containsAll(['mine', 'theirs']));

    await c.sync(manual: true);
    expect(reloads, 1, reason: 'nothing new received, nothing to reload');
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
    await wait(200);
    expect(fake.maxActive, 1);
    expect(fake.healthCalls - before, 2, reason: 'the running one, then one more');
  });

  test('a modification is sent a few seconds later', () async {
    final c = cubit(debounce: 50);
    await c.start();
    await device.journal.write(Modification.set('note', 'mine', {'title': 'Loyer et charges'}));
    await wait(10);
    expect(c.state.pending, 1, reason: 'shown at once');
    final before = fake.requests.length;
    await wait(300);
    expect(fake.requests.length, greaterThan(before));
    expect((await server.notes())['mine']!['title'], 'Loyer et charges');
    expect(c.state.pending, 0);
  });

  test('every period while the app is shown, never while it is hidden', () async {
    final c = cubit(period: 50);
    await c.start();
    await wait(260);
    final shown = fake.healthCalls;
    expect(shown, greaterThanOrEqualTo(4));
    c.paused();
    await wait(260);
    expect(fake.healthCalls, shown);
    await c.resumed();
    expect(fake.healthCalls, shown + 1, reason: 'back to the foreground');
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
}
