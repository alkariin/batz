// End-to-end: a revoked device, and a server lost then rebuilt from the
// devices, through real batz-web processes.
import 'dart:io';

import 'package:batz/data/server/certificate.dart';
import 'package:batz/data/server/server_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/field_merge_test.dart' show draftOf;
import '../support/ledger_fixture.dart';
import 'server_harness.dart';
import 'sync_device.dart';
import 'sync_e2e_test.dart' show idA, idB;

Matcher serverError(String code) => isA<ServerException>().having((e) => e.code, 'code', code);

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
    await seedLedger(a.ledger);
    await a.ledger.apply((l) => l.recordEntry('t1', 'l1', entry(cents: 4500, description: 'Coop')));
    await a.sync();
    await b.sync();
  });

  tearDown(() async {
    await a.close();
    await b.close();
    await server.stop();
    if (server.dataDir.existsSync()) server.dataDir.deleteSync(recursive: true);
  });

  /// Forgets the pairing and pairs with [s] again.
  Future<void> pairAgain(SimDevice d, LocalServer s) async {
    await d.server.forget();
    await d.pair(s);
  }

  /// The server reinstalled at the address the devices know: their pairing
  /// now points to [s], with the certificate pinned at pairing.
  Future<void> sameAddress(LocalServer s) async {
    for (final d in [a, b]) {
      d.pairing = await d.server.changeAddress(d.pairing!, s.address);
    }
  }

  test(
    'a revoked device is refused, its data stay; paired again, its unsent modifications go at the first exchange',
    () async {
      await b.server.revoke(b.pairing!, a.pairing!.deviceId);

      wallA += 1000;
      await a.ledger.apply((l) => l.recordEntry('t2', 'l2', entry(cents: 1200, description: 'Hors ligne')));
      final before = await a.state();
      await expectLater(a.sync(), throwsA(serverError('DEVICE_REVOKED')));
      expect(await a.state(), before, reason: 'nothing of the device is touched');
      expect((await a.ledger.ledger()).transactions.keys, containsAll(['t1', 't2']));

      await pairAgain(a, server);
      final report = await a.sync();
      expect(report.sentEntries, greaterThan(0));
      await b.sync();
      expect((await b.ledger.ledger()).transactions['t2']!.description, 'Hors ligne');
      expect(await b.state(), await a.state());
    },
  );

  for (final sameCertificate in [false, true]) {
    final variant = sameCertificate ? 'same certificate, database lost' : 'reinstalled with a new certificate';
    test('a lost server ($variant) is rebuilt from one device; the other pairs again '
        'and resynchronises without loss, unsent modifications included', () async {
      // A's last modification reached the server; B's did not.
      wallA += 1000;
      await a.ledger.apply((l) => l.updateEntry('t1', draftOf(l.transactions['t1']!, note: 'par A')));
      await a.sync();
      wallB += 2000;
      await b.ledger.apply((l) => l.updateEntry('t1', draftOf(l.transactions['t1']!, category: 'rent')));
      await b.ledger.apply((l) => l.recordEntry('t3', 'l3', entry(cents: 990, description: 'Pas encore envoyé')));

      // The server is lost and reinstalled at the same address.
      await server.stop();
      final Matcher refused;
      if (sameCertificate) {
        for (final f in server.dataDir.listSync().whereType<File>()) {
          if (f.path.contains('batz.db')) f.deleteSync();
        }
        server = await LocalServer.start(dataDir: server.dataDir);
        refused = serverError('DEVICE_KEY_INVALID');
      } else {
        server.dataDir.deleteSync(recursive: true);
        server = await LocalServer.start();
        refused = isA<CertificateMismatchException>();
      }
      await sameAddress(server);

      // The app reports it; A pairs again and rebuilds the server.
      await expectLater(a.sync(), throwsA(refused));
      await pairAgain(a, server);
      final rebuild = await a.sync();
      expect(rebuild.sentEntries, (await a.ledger.journal.entries()).length, reason: 'everything A holds');

      // B pairs again: no question (they share their origins), nothing lost.
      await expectLater(b.sync(), throwsA(refused));
      await pairAgain(b, server);
      await b.sync();
      await a.sync();

      final t1 = (await a.ledger.ledger()).transactions['t1']!;
      expect((t1.note, t1.line!.categoryId), ('par A', 'rent'));
      expect((await a.ledger.ledger()).transactions['t3']!.description, 'Pas encore envoyé');
      expect(await b.state(), await a.state());

      // The server is complete: a new device gets exactly the same.
      final d = await SimDevice.create('D');
      addTearDown(d.close);
      await d.pair(server);
      await d.sync();
      final state = await a.state();
      expect(await d.state(), state);
    });
  }

  test('a server restored from an older copy is an ordinary exchange', () async {
    // A copy of the server data while it holds the seed only.
    final copy = Directory.systemTemp.createTempSync('batz-copy');
    addTearDown(() => copy.deleteSync(recursive: true));
    await server.stop();
    await Process.run('cp', ['-a', '${server.dataDir.path}/.', copy.path]);
    server = await LocalServer.start(dataDir: server.dataDir);
    await sameAddress(server);

    wallA += 1000;
    await a.ledger.apply((l) => l.recordEntry('t4', 'l4', entry(cents: 400)));
    await a.sync();
    wallB += 1000;
    await b.ledger.apply((l) => l.recordEntry('t5', 'l5', entry(cents: 500)));
    await b.sync();

    // Restored: t4 and t5 are gone from the server, not from the devices.
    await server.stop();
    server.dataDir.deleteSync(recursive: true);
    await Process.run('cp', ['-a', '${copy.path}/.', server.dataDir.path]);
    server = await LocalServer.start(dataDir: server.dataDir);
    await sameAddress(server);

    await a.sync();
    await b.sync();
    await a.sync();
    expect((await a.ledger.ledger()).transactions.keys, containsAll(['t4', 't5']));
    expect(await b.state(), await a.state());
  });
}
