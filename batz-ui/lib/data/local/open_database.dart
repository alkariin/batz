import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import '../secret_store.dart';
import 'database.dart';

/// Name of the local database file in the app support directory.
const databaseFileName = 'batz.db';

/// Secret store key of the database encryption key.
const databaseKeyName = 'database_key';

/// The database file exists but its encryption key is gone (for example the
/// system keystore was reset). The data cannot be read; it will be recovered
/// from the server once synchronisation exists.
class DatabaseKeyLostException implements Exception {
  @override
  String toString() => 'DatabaseKeyLostException: the local database key is missing';
}

/// Returns the encryption key of the database, creating it on first launch.
///
/// The key is 32 random bytes in hex, used as a raw SQLCipher key (no key
/// derivation needed). It is written, then read back, before any database
/// is created with it.
Future<String> obtainDatabaseKey(SecretStore secrets, {required bool databaseExists}) async {
  final existing = await secrets.read(databaseKeyName);
  if (existing != null) return existing;
  if (databaseExists) throw DatabaseKeyLostException();

  final random = Random.secure();
  final key = List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  await secrets.write(databaseKeyName, key);
  if (await secrets.read(databaseKeyName) != key) {
    throw StateError('The database key could not be stored');
  }
  return key;
}

/// Opens the local database in [directory]. With [encrypt] (Android), the
/// database is encrypted with SQLCipher under a key kept by the system;
/// opening fails rather than fall back to an unencrypted database. Desktops
/// rely on the protection of the operating system.
Future<LocalDatabase> openLocalDatabase({
  required Directory directory,
  required SecretStore secrets,
  required bool encrypt,
}) async {
  await directory.create(recursive: true);
  final file = File('${directory.path}/$databaseFileName');
  final key = encrypt ? await obtainDatabaseKey(secrets, databaseExists: await file.exists()) : null;
  return LocalDatabase(NativeDatabase.createInBackground(file, setup: key == null ? null : (db) => unlock(db, key)));
}

/// Applies the SQLCipher key to a freshly opened connection, and checks
/// that SQLCipher is really there and that the key is the right one.
void unlock(Database db, String hexKey) {
  if (db.select('PRAGMA cipher_version').isEmpty) {
    throw StateError('SQLCipher is not available: refusing to store data unencrypted');
  }
  db.execute("PRAGMA key = \"x'$hexKey'\"");
  // Fails with "file is not a database" if the key is wrong.
  db.select('SELECT count(*) FROM sqlite_master');
}
