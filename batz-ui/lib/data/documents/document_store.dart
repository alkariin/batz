import 'package:drift/drift.dart';

import '../local/database.dart';

/// The copy of the documents' files on this device, by fingerprint: a table
/// of its own in the local database (encrypted on Android with the rest),
/// outside the journal and the derived tables. It is never synchronised:
/// the server keeps the files, each device downloads its copy.
class DocumentStore {
  DocumentStore(this._db);

  final LocalDatabase _db;
  Future<void>? _ready;

  Future<void> _ensureTable() => _ready ??= _db.customStatement(
    'CREATE TABLE IF NOT EXISTS document_files (fingerprint TEXT PRIMARY KEY, bytes BLOB NOT NULL)',
  );

  /// The fingerprints of the files held.
  Future<Set<String>> fingerprints() async {
    await _ensureTable();
    final rows = await _db.customSelect('SELECT fingerprint FROM document_files').get();
    return {for (final row in rows) row.read<String>('fingerprint')};
  }

  Future<Uint8List?> read(String fingerprint) async {
    await _ensureTable();
    final row = await _db
        .customSelect('SELECT bytes FROM document_files WHERE fingerprint = ?', variables: [Variable(fingerprint)])
        .getSingleOrNull();
    return row?.read<Uint8List>('bytes');
  }

  Future<void> save(String fingerprint, Uint8List bytes) async {
    await _ensureTable();
    await _db.customStatement('INSERT OR REPLACE INTO document_files (fingerprint, bytes) VALUES (?, ?)', [
      fingerprint,
      bytes,
    ]);
  }
}
