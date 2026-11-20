import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/ids.dart';
import '../../domain/journal/hlc.dart';
import '../../domain/journal/journal_entry.dart';
import 'database.dart';
import 'derived_tables.dart';

const _deviceIdKey = 'device_id';

/// Local state keys of the derived schema in place: its text, and the names
/// of its tables (to drop them once they are no longer part of the schema).
const derivedSchemaKey = 'derived_schema';
const derivedTablesKey = 'derived_tables';

final _sqlIdentifier = RegExp(r'^[a-z][a-z0-9_]*$');

/// The only way to change data: every write is a set of journal entries,
/// applied to the derived tables in the same transaction.
class Journal {
  Journal._(this._db, this.deviceId, this._clock, List<DerivedTable> tables)
    : _tables = {for (final t in tables) t.entity: t};

  /// Opens the journal of [db]. On the very first launch it creates the
  /// device identifier; on later ones it resumes the clock after the latest
  /// timestamp in the journal, so that time never goes backwards across
  /// restarts.
  ///
  /// If the derived [tables] differ from those in place (first launch, or a
  /// new version of the app), they are dropped, recreated and recomputed from
  /// the journal: derived tables never migrate.
  static Future<Journal> open(
    LocalDatabase db, {
    List<DerivedTable>? tables,
    int Function()? now,
    String Function() newDeviceId = newId,
  }) async {
    final deviceId = await db.transaction(() async {
      final row = await (db.select(db.localState)..where((s) => s.key.equals(_deviceIdKey))).getSingleOrNull();
      if (row != null) return row.value;
      final id = newDeviceId();
      await db.into(db.localState).insert(LocalStateCompanion.insert(key: _deviceIdKey, value: id));
      return id;
    });
    final maxHlc = db.journalEntries.hlc.max();
    final latest = await (db.selectOnly(
      db.journalEntries,
    )..addColumns([maxHlc])).map((r) => r.read(maxHlc)).getSingle();
    final clock = HlcClock(deviceId, last: latest == null ? null : Hlc.parse(latest), now: now);
    final journal = Journal._(db, deviceId, clock, tables ?? appDerivedTables);
    await journal._ensureDerivedSchema();
    return journal;
  }

  /// Whether the last [open] had to recreate the derived tables.
  bool get derivedTablesRebuilt => _derivedTablesRebuilt;
  var _derivedTablesRebuilt = false;

  Future<void> _ensureDerivedSchema() {
    final schema = derivedSchemaOf(_tables.values.toList());
    return _db.transaction(() async {
      final state = {for (final row in await _db.select(_db.localState).get()) row.key: row.value};
      if (state[derivedSchemaKey] == schema) return;

      final previous = state[derivedTablesKey] == null
          ? const <Object?>[]
          : jsonDecode(state[derivedTablesKey]!) as List<Object?>;
      final names = {...previous.whereType<String>(), ..._tables.values.map((t) => t.table)};
      for (final name in names) {
        if (!_sqlIdentifier.hasMatch(name)) throw StateError('Invalid derived table name: $name');
        await _db.customStatement('DROP TABLE IF EXISTS $name');
      }
      for (final table in _tables.values) {
        for (final statement in table.createStatements) {
          await _db.customStatement(statement);
        }
      }
      await _rebuildContents();
      for (final entry in {
        derivedSchemaKey: schema,
        derivedTablesKey: jsonEncode([for (final t in _tables.values) t.table]..sort()),
      }.entries) {
        await _db
            .into(_db.localState)
            .insertOnConflictUpdate(LocalStateCompanion.insert(key: entry.key, value: entry.value));
      }
      _derivedTablesRebuilt = true;
    });
  }

  final LocalDatabase _db;
  final HlcClock _clock;
  final Map<String, DerivedTable> _tables;

  /// Identifier of this installation, created at the first launch.
  final String deviceId;

  /// Records [modification] and applies it, atomically: either every entry
  /// is stored and applied, or none is. Returns the shared timestamp.
  Future<Hlc> write(Modification modification) async {
    for (final change in modification.changes) {
      _columnFor(change.entity, change.field, strict: true);
    }
    return _db.transaction(() async {
      final hlc = _clock.tick();
      for (final change in modification.changes) {
        final entry = JournalEntry(hlc, change);
        await _insert(entry);
        await _apply(entry);
      }
      return hlc;
    });
  }

  /// Integrates entries made on other devices (or replayed): unknown ones are
  /// stored and applied, known ones are ignored. Entries of an entity or
  /// field this version does not know are kept in the journal for a later
  /// version to apply. Returns how many entries were new.
  Future<int> merge(Iterable<JournalEntry> entries) {
    return _db.transaction(() async {
      var added = 0;
      for (final entry in entries) {
        _clock.observe(entry.hlc);
        if (await _insert(entry)) {
          added++;
          await _apply(entry);
        }
      }
      return added;
    });
  }

  /// Recomputes every derived table from the journal.
  Future<void> rebuild() => _db.transaction(_rebuildContents);

  Future<void> _rebuildContents() async {
    await _db.delete(_db.fieldVersions).go();
    for (final table in _tables.values) {
      await _db.customStatement('DELETE FROM ${table.table}');
    }
    final rows = await _db.select(_db.journalEntries).get();
    for (final row in rows) {
      await _apply(_toEntry(row));
    }
  }

  /// Every entry of the journal, oldest first.
  Future<List<JournalEntry>> entries() async {
    final rows = await (_db.select(_db.journalEntries)..orderBy([(j) => OrderingTerm.asc(j.hlc)])).get();
    return rows.map(_toEntry).toList();
  }

  JournalEntry _toEntry(JournalRow row) => JournalEntry(
    Hlc.parse(row.hlc),
    FieldChange(row.entity, row.recordId, row.field, JournalEntry.decodeValue(row.value)),
  );

  /// Stores [entry]; returns false if it was already there.
  Future<bool> _insert(JournalEntry entry) async {
    await _db
        .into(_db.journalEntries)
        .insert(
          JournalEntriesCompanion.insert(
            hlc: entry.hlc.encode(),
            entity: entry.entity,
            recordId: entry.recordId,
            field: entry.field,
            value: entry.encodedValue,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    // Inside the transaction, changes() reports this very statement.
    return await _changes() > 0;
  }

  Future<int> _changes() async {
    final row = await _db.customSelect('SELECT changes() AS n').getSingle();
    return row.read<int>('n');
  }

  /// Applies [entry] to its derived table if it is the latest change of its
  /// field.
  Future<void> _apply(JournalEntry entry) async {
    final table = _tables[entry.entity];
    final column = _columnFor(entry.entity, entry.field, strict: false);
    if (table == null || column == null) return;

    final current =
        await (_db.select(_db.fieldVersions)..where(
              (v) => v.entity.equals(entry.entity) & v.recordId.equals(entry.recordId) & v.field.equals(entry.field),
            ))
            .getSingleOrNull();
    if (!supersedes(entry.hlc, current == null ? null : Hlc.parse(current.hlc))) return;

    await _db
        .into(_db.fieldVersions)
        .insertOnConflictUpdate(
          FieldVersionsCompanion.insert(
            entity: entry.entity,
            recordId: entry.recordId,
            field: entry.field,
            hlc: entry.hlc.encode(),
          ),
        );
    await _db.customStatement(
      'INSERT INTO ${table.table} (id, $column) VALUES (?, ?) '
      'ON CONFLICT (id) DO UPDATE SET $column = excluded.$column',
      [entry.recordId, _sqlValue(entry.value)],
    );
  }

  /// The column that stores [field] of [entity], or null if this version does
  /// not know it. With [strict], an unknown one is a programming error.
  String? _columnFor(String entity, String field, {required bool strict}) {
    final table = _tables[entity];
    final column = field == deletedField ? 'deleted' : table?.columns[field]?.name;
    if (table == null || column == null) {
      if (strict) throw ArgumentError('No derived table for $entity.$field');
      return null;
    }
    return column;
  }

  static Object? _sqlValue(Object? value) => switch (value) {
    true => 1,
    false => 0,
    _ => value,
  };
}
