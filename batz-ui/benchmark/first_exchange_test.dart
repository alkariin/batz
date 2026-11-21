// Measures a first exchange of 20 000 journal entries on the development
// machine, against a real batz-web. Not part of the regular suite; run it with
//
//   flutter test benchmark/first_exchange_test.dart
//
// The result is recorded in docs/decisions.md, « Reference measures ».
import 'dart:io';

import 'package:batz/data/local/database.dart';
import 'package:batz/data/local/journal.dart';
import 'package:batz/data/secret_store.dart';
import 'package:batz/data/server/server_client.dart';
import 'package:batz/data/server/server_repository.dart';
import 'package:batz/data/sync/sync_engine.dart';
import 'package:batz/data/sync/sync_store.dart';
import 'package:batz/domain/journal/hlc.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/e2e/server_harness.dart';

const _entries = 20000;
const _origin = 'aaaaaaaa-0000-4000-8000-000000000000';

/// A device as in production: a database file opened in a background
/// isolate.
Future<(LocalDatabase, Journal)> _device(Directory dir) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = LocalDatabase(NativeDatabase.createInBackground(File('${dir.path}/batz.db')));
  return (db, await Journal.open(db));
}

/// 20 000 entries: 1 667 transactions of a year with their line, 12 entries
/// each, as the app writes them.
List<JournalEntry> _history() {
  final out = <JournalEntry>[];
  var millis = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
  for (var i = 0; out.length < _entries; i++) {
    final hlc = Hlc(millis += 60000, 0, _origin);
    final fields = <(String, String, String, Object?)>[
      ('transaction', 't$i', 'accountId', 'account-cash'),
      ('transaction', 't$i', 'date', '2026-${(i % 12 + 1).toString().padLeft(2, '0')}-15'),
      ('transaction', 't$i', 'amount', -(100 + i)),
      ('transaction', 't$i', 'counterpartAccountId', null),
      ('transaction', 't$i', 'description', 'Achat n°$i chez un commerçant'),
      ('transaction', 't$i', 'note', ''),
      ('transaction', 't$i', 'status', 'validated'),
      ('transactionLine', 'l$i', 'transactionId', 't$i'),
      ('transactionLine', 'l$i', 'categoryId', 'category-food'),
      ('transactionLine', 'l$i', 'amount', -(100 + i)),
      ('transactionLine', 'l$i', 'periodStart', '2026-01-01'),
      ('transactionLine', 'l$i', 'periodEnd', '2026-12-31'),
    ];
    for (final (entity, record, field, value) in fields) {
      if (out.length < _entries) out.add(JournalEntry(hlc, FieldChange(entity, record, field, value)));
    }
  }
  return out;
}

void main() {
  test('first exchange of $_entries entries', () async {
    final server = await LocalServer.start();
    final dirs = [for (var i = 0; i < 2; i++) Directory.systemTemp.createTempSync('batz-bench')];
    addTearDown(() async {
      await server.stop();
      server.dataDir.deleteSync(recursive: true);
      for (final d in dirs) {
        d.deleteSync(recursive: true);
      }
    });

    Future<Duration> exchange(LocalDatabase db, Journal journal, String name) async {
      final repo = ServerRepository(MemorySecretStore());
      final pairing = await repo.pair(
        address: server.address,
        code: (await server.pairingCode()).code,
        deviceName: name,
      );
      final client = ServerClient(pairing.address, pin: pairing.fingerprint, deviceKey: pairing.deviceKey);
      final watch = Stopwatch()..start();
      final report = await SyncEngine(journal, SyncStore(db)).run(client, pairingId: pairing.deviceId);
      watch.stop();
      client.close();
      // ignore: avoid_print
      print(
        '$name: ${watch.elapsedMilliseconds} ms, ${report.calls} calls, '
        'sent ${report.sentEntries}, received ${report.receivedEntries}',
      );
      return watch.elapsed;
    }

    final (dbA, journalA) = await _device(dirs[0]);
    await journalA.merge(_history());
    expect(await journalA.entries(), hasLength(_entries));
    await exchange(dbA, journalA, 'first exchange of a device holding them, empty server');

    final (dbB, journalB) = await _device(dirs[1]);
    await exchange(dbB, journalB, 'first exchange of a new device');
    expect(await journalB.entries(), hasLength(_entries));
    expect(await journalB.knownState(), await journalA.knownState());
    await dbA.close();
    await dbB.close();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
