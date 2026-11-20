import 'package:batz/data/server/server_client.dart';
import 'package:batz/data/sync/sync_engine.dart';
import 'package:batz/data/sync/sync_protocol.dart';
import 'package:batz/data/sync/sync_store.dart';
import 'package:batz/domain/journal/hlc.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/journal/known_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_server.dart';
import '../support/journal_harness.dart';

const me = '11111111-0000-4000-8000-000000000000';
const other = '22222222-0000-4000-8000-000000000000';

void main() {
  late Harness device, server;
  late SyncEngine engine;
  late FakeServer fake;

  setUp(() async {
    device = await Harness.open(deviceId: me);
    server = await Harness.open(deviceId: other);
    engine = SyncEngine(device.journal, SyncStore(device.db), pageSize: 2, requestedPageSize: 2);
    fake = FakeServer(server.journal);
    for (var i = 0; i < 3; i++) {
      await device.journal.write(Modification.set('note', 'mine$i', {'title': 'm$i'}));
      await server.journal.write(Modification.set('note', 'theirs$i', {'title': 't$i'}));
    }
  });
  tearDown(() async {
    await device.close();
    await server.close();
  });

  test('an exchange sends and receives everything, page by page', () async {
    final report = await engine.run(fake, pairingId: 'p');
    expect(report.sentEntries, 3);
    expect(report.receivedEntries, 3);
    expect(await device.notes(), await server.notes());
    expect(fake.requests.first.page.isEmpty, isTrue, reason: 'the first call learns the server state');
    expect(fake.requests.map((r) => r.page.entries.length).every((n) => n <= 2), isTrue);
    expect((await SyncStore(device.db).read('p'))!.known, await server.journal.knownState());
  });

  test('when the server state changed under the exchange, it starts again from it', () async {
    var calls = 0;
    fake.restore = () async {
      // After the second call the server is restored from an older copy:
      // it loses the last entry the device sent.
      if (++calls != 2) return;
      await server.db.customStatement("DELETE FROM journal WHERE record_id = 'mine1'");
    };
    final report = await engine.run(fake, pairingId: 'p');
    expect(fake.conflicts, 1, reason: 'the page continuing from mine1 was refused once');
    expect(report.sentEntries, 4, reason: 'mine1 was sent again');
    await server.journal.rebuild();
    expect(await device.notes(), await server.notes());
    expect(await server.journal.knownState(), await device.journal.knownState());
  });

  test('a server that announces more entries but sends none breaks the protocol', () async {
    fake.alter = (r) =>
        SyncResponse(serverTime: r.serverTime, known: r.known, page: JournalPage(const [], more: true), added: 0);
    await expectLater(engine.run(fake, pairingId: 'p'), throwsA(isA<SyncProtocolException>()));
  });

  test('a page from the server that would leave a gap is refused, nothing integrated', () async {
    fake.alter = (r) => SyncResponse(
      serverTime: r.serverTime,
      known: r.known,
      page: JournalPage(r.page.entries, since: KnownState({other: _later(other)}), more: r.page.more),
      added: r.added,
    );
    await expectLater(engine.run(fake, pairingId: 'p'), throwsA(isA<SyncProtocolException>()));
    expect((await device.notes()).keys.where((k) => k.startsWith('theirs')), isEmpty);
  });

  test('a malformed answer is a protocol error', () {
    expect(() => SyncResponse.fromJson({'protocol': 1}), throwsA(isA<SyncProtocolException>()));
    expect(() => SyncResponse.fromJson({'protocol': 2}), throwsA(isA<SyncProtocolException>()));
    expect(() => SyncResponse.fromJson('nope'), throwsA(isA<SyncProtocolException>()));
  });

  test('an interrupted exchange keeps what was integrated and resumes', () async {
    fake.failNext = ServerUnreachableException('off');
    await expectLater(engine.run(fake, pairingId: 'p'), throwsA(isA<ServerUnreachableException>()));
    expect((await SyncStore(device.db).read('p')), isNull, reason: 'never reached the server');
    await engine.run(fake, pairingId: 'p');
    expect(await device.notes(), await server.notes());
    expect((await SyncStore(device.db).read('p'))!.lastSuccess, isNotNull);
  });

  test('the offset of the server clock is measured', () async {
    fake = FakeServer(server.journal, clock: () => DateTime.now().add(const Duration(minutes: 7)));
    final report = await engine.run(fake, pairingId: 'p');
    expect(report.clockOffset.inSeconds, closeTo(7 * 60, 2));
  });
}

/// A timestamp of [origin] later than anything in the tests.
Hlc _later(String origin) => Hlc(9999999999999, 0, origin);
