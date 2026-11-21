// End-to-end: devices exchange their journal through a real batz-web
// process, with the app's operations and sync engine.
import 'package:batz/data/server/server_client.dart';
import 'package:batz/data/sync/sync_engine.dart';
import 'package:batz/domain/journal/known_state.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/field_merge_test.dart' show draftOf;
import '../support/ledger_fixture.dart';
import 'server_harness.dart';
import 'sync_device.dart';

const idA = 'aaaaaaaa-0000-4000-8000-000000000000';
const idB = 'bbbbbbbb-0000-4000-8000-000000000000';
const idC = 'cccccccc-0000-4000-8000-000000000000';

void main() {
  late LocalServer server;
  late int wallA, wallB;
  late SimDevice a, b;

  setUp(() async {
    server = await LocalServer.start();
    wallA = wallB = DateTime.utc(2026, 11, 20).millisecondsSinceEpoch;
    a = await SimDevice.create('A', deviceId: idA, now: () => wallA);
    b = await SimDevice.create('B', deviceId: idB, now: () => wallB);
    await a.pair(server);
    await b.pair(server);
    // A seeds the ledger; both devices start from it.
    await seedLedger(a.ledger);
    await a.ledger.apply((l) => l.recordEntry('t1', 'l1', entry(cents: 4500, description: 'Coop')));
    await a.sync();
    await b.sync();
    expect(await b.state(), await a.state());
  });

  tearDown(() async {
    await a.close();
    await b.close();
    await server.stop();
    server.dataDir.deleteSync(recursive: true);
  });

  Future<LedgerTransaction?> t1(SimDevice d) async => (await d.ledger.ledger()).transactions['t1'];

  test('offline, one device corrects the note, the other changes the category: both are kept on both', () async {
    wallA += 1000;
    await a.ledger.apply((l) => l.updateEntry('t1', draftOf(l.transactions['t1']!, note: 'Avec les fruits')));
    wallB += 2000;
    await b.ledger.apply((l) => l.updateEntry('t1', draftOf(l.transactions['t1']!, category: 'rent')));

    await a.sync();
    final report = await b.sync();
    expect(report.receivedEntries, 1, reason: 'only the note');
    await a.sync();

    for (final d in [a, b]) {
      final t = (await t1(d))!;
      expect((t.note, t.line!.categoryId, t.description), ('Avec les fruits', 'rent', 'Coop'), reason: d.name);
    }
    expect(await b.state(), await a.state());
  });

  for (final order in [
    ['A', 'B', 'A'],
    ['B', 'A', 'B'],
  ]) {
    test('the same field changed on both: the latest wins everywhere, exchanges ${order.join(', ')}', () async {
      wallB += 1000;
      await b.ledger.apply((l) => l.updateEntry('t1', draftOf(l.transactions['t1']!, note: 'older, from B')));
      wallA += 5000;
      await a.ledger.apply((l) => l.updateEntry('t1', draftOf(l.transactions['t1']!, note: 'latest, from A')));
      for (final name in order) {
        await (name == 'A' ? a : b).sync();
      }
      expect((await t1(a))!.note, 'latest, from A');
      expect((await t1(b))!.note, 'latest, from A');
      expect(await b.state(), await a.state());
    });

    test('a deletion spreads, an older modification arriving later does not bring the record back, '
        'exchanges ${order.join(', ')}', () async {
      wallB += 1000;
      await b.ledger.apply((l) => l.updateEntry('t1', draftOf(l.transactions['t1']!, note: 'edited before')));
      wallA += 5000;
      await a.ledger.apply((l) => l.deleteTransaction('t1'));
      for (final name in order) {
        await (name == 'A' ? a : b).sync();
      }
      expect(await t1(a), isNull);
      expect(await t1(b), isNull);
      expect((await b.ledger.ledger()).transactions, isEmpty);
      expect(await b.state(), await a.state());
    });
  }

  test('an exchange cut between two pages resumes at the next one, without loss or duplicate', () async {
    // A holds many modifications; it sends them five entries at a time.
    final sender = await SimDevice.create('sender', deviceId: idC, pageSize: 5, requestedPageSize: 4);
    addTearDown(sender.close);
    await sender.pair(server);
    await sender.sync();
    for (var i = 0; i < 12; i++) {
      await sender.ledger.apply((l) => l.recordEntry('s$i', 'sl$i', entry(cents: 100 + i, description: 'n°$i')));
    }

    // Cut before the third call reaches the server, then once the server has
    // integrated the fifth one but its answer is lost.
    await expectLater(sender.sync(wrap: (c) => CutTransport(c, failAt: 3)), throwsA(isA<ServerUnreachableException>()));
    await expectLater(
      sender.sync(wrap: (c) => CutTransport(c, failAt: 2, afterServer: true)),
      throwsA(isA<ServerUnreachableException>()),
    );
    await sender.sync();

    // B receives them four entries at a time, also cut twice.
    final receiver = await SimDevice.create('receiver', pageSize: 5, requestedPageSize: 4);
    addTearDown(receiver.close);
    await receiver.pair(server);
    await expectLater(
      receiver.sync(wrap: (c) => CutTransport(c, failAt: 4)),
      throwsA(isA<ServerUnreachableException>()),
    );
    await _expectPrefixes(receiver, sender);
    await expectLater(
      receiver.sync(wrap: (c) => CutTransport(c, failAt: 3, afterServer: true)),
      throwsA(isA<ServerUnreachableException>()),
    );
    await _expectPrefixes(receiver, sender);
    final report = await receiver.sync();
    expect(report.calls, greaterThan(5), reason: 'several pages');

    final journal = await sender.ledger.journal.entries();
    expect(await receiver.ledger.journal.entries(), hasLength(journal.length), reason: 'no duplicate');
    final state = await sender.state();
    expect(await receiver.state(), state);
    expect((await receiver.ledger.ledger()).transactions, hasLength(13));
  });

  group('first exchange of a device used separately', () {
    late SimDevice c;
    setUp(() async {
      c = await SimDevice.create('C', deviceId: idC);
      await c.ledger.apply(
        (l) => l.createAccount('c-own', const AccountDraft(name: 'Compte de C', type: AccountType.cash)),
      );
      await c.pair(server);
    });
    tearDown(() => c.close());

    test('the question comes first, nothing exchanged', () async {
      final before = await c.state();
      await expectLater(c.sync(), throwsA(isA<UnrelatedDataException>()));
      expect(await c.state(), before);
      await a.sync();
      expect((await a.ledger.ledger()).accounts.containsKey('c-own'), isFalse);
    });

    test('replace: the device then holds exactly the server data', () async {
      final report = await c.replace();
      expect(report.replaced, isTrue);
      expect(await c.state(), await a.state(), reason: 'tables, journal and field versions');
      expect(c.ledger.journal.deviceId, isNot(idC));
      expect((await c.ledger.ledger()).accounts.containsKey('c-own'), isFalse);

      // From then on, an ordinary device.
      await c.ledger.apply((l) => l.createAccount('c-new', const AccountDraft(name: 'Après', type: AccountType.cash)));
      await c.sync();
      await a.sync();
      expect((await a.ledger.ledger()).accounts.keys, contains('c-new'));
      expect((await a.ledger.ledger()).accounts.containsKey('c-own'), isFalse);
    });

    test('merge: both data sets end up on every device', () async {
      await c.sync(merge: true);
      await a.sync();
      await b.sync();
      expect((await a.ledger.ledger()).accounts.keys, contains('c-own'));
      expect((await c.ledger.ledger()).transactions.keys, contains('t1'));
      expect(await c.state(), await a.state());
      expect(await b.state(), await a.state());
    });
  });

  test(
    'the date of the last exchange and the server state are remembered; pending modifications are counted',
    () async {
      final memory = (await a.store.read(a.pairing!.deviceId))!;
      expect(memory.lastSuccess, isNotNull);
      expect(memory.known, await a.ledger.journal.knownState());
      expect(await a.ledger.journal.pendingFor(memory.known), 0);

      wallA += 1000;
      await a.ledger.apply((l) => l.updateEntry('t1', draftOf(l.transactions['t1']!, note: 'one')));
      wallA += 1000;
      await a.ledger.apply((l) => l.recordEntry('t2', 'l2', entry(cents: 300)));
      expect(await a.ledger.journal.pendingFor(memory.known), 2);
      await a.sync();
      final after = (await a.store.read(a.pairing!.deviceId))!;
      expect(await a.ledger.journal.pendingFor(after.known), 0);
      expect(after.lastSuccess!.isBefore(memory.lastSuccess!), isFalse);
      expect(await a.store.read('another pairing'), isNull);
    },
  );
}

/// [copy] holds, for each origin, exactly [source]'s entries of that origin
/// up to its known timestamp: an interrupted exchange never leaves a gap.
Future<void> _expectPrefixes(SimDevice copy, SimDevice source) async {
  final known = await copy.ledger.journal.knownState();
  final held = {for (final e in await copy.ledger.journal.entries()) '${e.hlc} ${e.change}'};
  final expected = {
    for (final e in await source.ledger.journal.entries())
      if (KnownState(known.latest).holds(e.hlc)) '${e.hlc} ${e.change}',
  };
  expect(held, expected);
}
