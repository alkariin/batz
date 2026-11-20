import 'dart:io';

import 'package:batz/data/local/journal.dart';
import 'package:batz/data/local/open_database.dart';
import 'package:batz/data/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('batz-open'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('database key', () {
    test('is created on first launch, kept by the secret store, then reused', () async {
      final secrets = MemorySecretStore();
      final key = await obtainDatabaseKey(secrets, databaseExists: false);
      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(secrets.values[databaseKeyName], key);
      expect(await obtainDatabaseKey(secrets, databaseExists: true), key);
    });

    test('two installations get different keys', () async {
      final a = await obtainDatabaseKey(MemorySecretStore(), databaseExists: false);
      final b = await obtainDatabaseKey(MemorySecretStore(), databaseExists: false);
      expect(a, isNot(b));
    });

    test('a database whose key is gone is reported, never replaced by a new key', () async {
      final secrets = MemorySecretStore();
      await expectLater(obtainDatabaseKey(secrets, databaseExists: true), throwsA(isA<DatabaseKeyLostException>()));
      expect(secrets.values, isEmpty);
    });

    test('a store that does not keep the key is detected', () async {
      await expectLater(obtainDatabaseKey(_ForgetfulStore(), databaseExists: false), throwsStateError);
    });
  });

  group('opening', () {
    test('desktop: a plain database, with its device identifier, kept across launches', () async {
      final secrets = MemorySecretStore();
      var db = await openLocalDatabase(directory: dir, secrets: secrets, encrypt: false);
      final id = (await Journal.open(db)).deviceId;
      await db.close();

      final header = File('${dir.path}/$databaseFileName').readAsBytesSync().sublist(0, 15);
      expect(String.fromCharCodes(header), 'SQLite format 3');
      expect(secrets.values, isEmpty, reason: 'no key on desktops');

      db = await openLocalDatabase(directory: dir, secrets: secrets, encrypt: false);
      expect((await Journal.open(db)).deviceId, id);
      await db.close();
    });

    test('Android: refuses to open without SQLCipher rather than store data in clear', () async {
      // Tests run on the desktop build of SQLite, without SQLCipher: exactly
      // the situation where encryption must fail closed.
      final db = await openLocalDatabase(directory: dir, secrets: MemorySecretStore(), encrypt: true);
      await expectLater(Journal.open(db), throwsA(anything));
      await db.close();
    });
  });
}

class _ForgetfulStore extends MemorySecretStore {
  @override
  Future<void> write(String key, String value) async {}
}
