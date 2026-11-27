// The export between devices, through a real batz-web: it creates no
// journal entry, needs no server, and two synchronised devices produce
// the same CSV files, byte for byte.
import 'dart:math';

import 'package:archive/archive.dart' show ZipDecoder;
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/export/export_archive.dart';
import 'package:batz/domain/export/ledger_export.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ledger_fixture.dart';
import '../support/random_operations.dart';
import 'server_harness.dart';
import 'sync_device.dart';

void main() {
  test('two synchronised devices produce the same CSV files; exporting writes nothing and needs no server', () async {
    final r = Random(11);
    final server = await LocalServer.start();
    addTearDown(() async {
      await server.stop();
      server.dataDir.deleteSync(recursive: true);
    });
    var wallA = DateTime.utc(2026, 11, 21, 10).millisecondsSinceEpoch, wallB = wallA + 90000;
    final a = await SimDevice.create('A', deviceId: 'aaaaaaaa-0000-4000-8000-000000000000', now: () => wallA);
    final b = await SimDevice.create('B', deviceId: 'bbbbbbbb-0000-4000-8000-000000000000', now: () => wallB);
    addTearDown(a.close);
    addTearDown(b.close);
    for (final d in [a, b]) {
      await d.pair(server);
    }
    await seedLedger(a.ledger);
    await a.sync();
    await b.sync();

    // Both devices enter data offline, then exchange now and then.
    var applied = 0;
    for (var step = 0; step < 120; step++) {
      final d = r.nextBool() ? a : b;
      if (d == a) {
        wallA += r.nextInt(3000);
      } else {
        wallB += r.nextInt(3000);
      }
      if (r.nextInt(8) == 0) {
        await d.sync();
        continue;
      }
      try {
        final m = randomOperation(await d.ledger.ledger(), r, '${d.name}-$step');
        if (m == null) continue;
        await d.ledger.repository.write(m);
        applied++;
      } on LedgerException {
        // Refused by the domain.
      }
    }
    expect(applied, greaterThan(50));
    for (var pass = 0; pass < 2; pass++) {
      await a.sync();
      await b.sync();
    }

    final today = CalendarDate(2026, 11, 21);
    final ledgerA = await a.ledger.ledger(), ledgerB = await b.ledger.ledger();
    expect(ledgerB.transactions.length, ledgerA.transactions.length);
    final filesA = {for (final f in exportFiles(ledgerA)) f.name: f.bytes};
    final filesB = {for (final f in exportFiles(ledgerB)) f.name: f.bytes};
    expect(filesA, hasLength(18));
    expect(filesB, filesA, reason: 'the same CSV files on both devices');

    // Exporting writes no entry to the journal: the journal is the same
    // before and after, and the next exchange has nothing to send.
    final before = await a.ledger.journal.entries();
    final archive = buildExportArchive(ledgerA, date: today, appVersion: '0.8.0-alpha');
    final zip = ZipDecoder().decodeBytes(archive.bytes, verify: true);
    for (final MapEntry(key: name, value: bytes) in filesA.entries) {
      expect(zip.findFile(name)!.content, bytes, reason: name);
    }
    final after = await a.ledger.journal.entries();
    expect(
      after.map((e) => (e.hlc, e.entity, e.recordId, e.field)),
      before.map((e) => (e.hlc, e.entity, e.recordId, e.field)),
    );
    expect((await a.sync()).sentEntries, 0);

    // Without the server, the export is the same.
    await server.stop();
    final offline = buildExportArchive(await b.ledger.ledger(), date: today, appVersion: '0.8.0-alpha');
    final offlineZip = ZipDecoder().decodeBytes(offline.bytes, verify: true);
    for (final MapEntry(key: name, value: bytes) in filesA.entries) {
      expect(offlineZip.findFile(name)!.content, bytes, reason: name);
    }
    expect((offline.csvFiles, offline.transactions), (18, ledgerA.transactions.length));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
