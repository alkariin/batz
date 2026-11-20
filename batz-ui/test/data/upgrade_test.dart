import 'dart:io';

import 'package:batz/data/local/journal.dart';
import 'package:batz/data/local/open_database.dart';
import 'package:batz/data/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A database written by version 0.1.0 (see test/fixtures/README.md).
const _fixture = 'test/fixtures/v0.1.0/batz.db';
const _fixtureDeviceId = 'a0000000-0000-4000-8000-000000000001';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('batz-upgrade');
    File(_fixture).copySync('${dir.path}/$databaseFileName');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a database of version 0.1.0 opens with this version, device identifier kept', () async {
    final db = await openLocalDatabase(directory: dir, secrets: MemorySecretStore(), encrypt: false);
    final journal = await Journal.open(db);

    expect(journal.deviceId, _fixtureDeviceId);
    expect(journal.derivedTablesRebuilt, isTrue, reason: '0.1.0 had no derived table');
    final entries = await journal.entries();
    expect(entries, hasLength(3));
    expect(entries.map((e) => e.field), containsAll(['name', 'type', 'archived']));
    await db.close();

    // The next launch finds the schema in place and changes nothing.
    final again = await openLocalDatabase(directory: dir, secrets: MemorySecretStore(), encrypt: false);
    final reopened = await Journal.open(again);
    expect(reopened.deviceId, _fixtureDeviceId);
    expect(reopened.derivedTablesRebuilt, isFalse);
    await again.close();
  });
}
