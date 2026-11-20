import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/ids.dart';
import '../../domain/journal/hlc.dart';
import '../../domain/journal/journal_entry.dart';
import '../../domain/journal/known_state.dart';
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
  ///
  /// Only the fields whose value changes are written: a field that already
  /// holds the value, set by an earlier entry, is left out. Screens submit
  /// every field of a record; without this rule, the latest modification
  /// would also overwrite, once synchronised, the fields another device
  /// changed in the meantime. When no field changes, nothing is written and
  /// null is returned.
  Future<Hlc?> write(Modification modification) async {
    for (final change in modification.changes) {
      _columnFor(change.entity, change.field, strict: true);
    }
    return _db.transaction(() async {
      final changed = [
        for (final change in modification.changes)
          if (await _currentValue(change.entity, change.recordId, change.field) != jsonEncode(change.value)) change,
      ];
      if (changed.isEmpty) return null;
      final hlc = _clock.tick();
      for (final change in changed) {
        final entry = JournalEntry(hlc, change);
        await _insert(entry);
        await _apply(entry);
      }
      return hlc;
    });
  }

  /// The JSON-encoded value of the entry that gives [field] its current
  /// value, or null if no entry ever set it.
  Future<String?> _currentValue(String entity, String recordId, String field) async {
    final row = await _db
        .customSelect(
          'SELECT j.value AS value FROM field_versions v JOIN journal j '
          'ON j.hlc = v.hlc AND j.entity = v.entity AND j.record_id = v.record_id AND j.field = v.field '
          'WHERE v.entity = ? AND v.record_id = ? AND v.field = ?',
          variables: [Variable.withString(entity), Variable.withString(recordId), Variable.withString(field)],
        )
        .getSingleOrNull();
    return row?.read<String>('value');
  }

  /// Integrates entries made on other devices (or replayed): unknown ones are
  /// stored and applied, known ones are ignored. Entries of an entity or
  /// field this version does not know are kept in the journal for a later
  /// version to apply. Returns how many entries were new.
  Future<int> merge(Iterable<JournalEntry> entries) => _db.transaction(() => _merge(entries));

  /// Stores the [entries] that are new and applies them, in a few set-based
  /// statements rather than one round trip per entry: a first exchange
  /// brings tens of thousands of entries. The result is the one of applying
  /// them one by one with [supersedes].
  Future<int> _merge(Iterable<JournalEntry> entries) async {
    final list = entries.toList();
    if (list.isEmpty) return 0;
    _clock.observe(list.map((e) => e.hlc).reduce((a, b) => a > b ? a : b));
    await _db.customStatement(
      'CREATE TEMP TABLE IF NOT EXISTS incoming (hlc TEXT, entity TEXT, record_id TEXT, field TEXT, value TEXT, '
      'PRIMARY KEY (hlc, entity, record_id, field))',
    );
    await _db.customStatement('DELETE FROM temp.incoming');
    const rowsPerStatement = 150;
    for (var start = 0; start < list.length; start += rowsPerStatement) {
      final chunk = list.sublist(start, (start + rowsPerStatement).clamp(0, list.length));
      await _db.customStatement(
        'INSERT OR IGNORE INTO temp.incoming (hlc, entity, record_id, field, value) VALUES '
        '${List.filled(chunk.length, '(?, ?, ?, ?, ?)').join(', ')}',
        [
          for (final e in chunk) ...[e.hlc.encode(), e.entity, e.recordId, e.field, e.encodedValue],
        ],
      );
    }
    // Only the entries this journal does not hold yet.
    await _db.customStatement(
      'DELETE FROM temp.incoming WHERE EXISTS (SELECT 1 FROM journal j WHERE j.hlc = incoming.hlc '
      'AND j.entity = incoming.entity AND j.record_id = incoming.record_id AND j.field = incoming.field)',
    );
    await _db.customStatement(
      'INSERT INTO journal (hlc, entity, record_id, field, value) '
      'SELECT hlc, entity, record_id, field, value FROM temp.incoming',
    );
    final added = await _changes();
    if (added > 0) {
      await _applyLatest(
        'SELECT entity, record_id, field, MAX(hlc) AS hlc FROM temp.incoming GROUP BY entity, record_id, field',
      );
    }
    await _db.customStatement('DELETE FROM temp.incoming');
    return added;
  }

  /// Applies, for each field of [latestSql] (entity, record_id, field, hlc:
  /// the latest of a set of journal entries per field), its entry if it is
  /// newer than the one that gives the field its current value. Fields this
  /// version does not know stay in the journal only.
  Future<void> _applyLatest(String latestSql) async {
    final known = [
      for (final table in _tables.values)
        for (final field in [deletedField, ...table.columns.keys]) (table.entity, field),
    ];
    if (known.isEmpty) return;
    await _db.customStatement('DROP TABLE IF EXISTS temp.latest');
    await _db.customStatement(
      'CREATE TEMP TABLE latest AS SELECT l.* FROM ($latestSql) l '
      'WHERE (l.entity, l.field) IN (VALUES ${List.filled(known.length, '(?, ?)').join(', ')}) '
      'AND NOT EXISTS (SELECT 1 FROM field_versions v WHERE v.entity = l.entity AND v.record_id = l.record_id '
      'AND v.field = l.field AND v.hlc >= l.hlc)',
      [
        for (final (entity, field) in known) ...[entity, field],
      ],
    );
    await _db.customStatement(
      'INSERT INTO field_versions (entity, record_id, field, hlc) SELECT entity, record_id, field, hlc '
      'FROM temp.latest WHERE true '
      'ON CONFLICT (entity, record_id, field) DO UPDATE SET hlc = excluded.hlc',
    );
    for (final (entity, field) in known) {
      final table = _tables[entity]!;
      final column = _columnFor(entity, field, strict: true)!;
      // json_extract turns the JSON text into the SQL value: true and false
      // become 1 and 0, like [_sqlValue].
      await _db.customStatement(
        'INSERT INTO ${table.table} (id, $column) '
        "SELECT l.record_id, json_extract(j.value, '\$') FROM temp.latest l JOIN journal j "
        'ON j.hlc = l.hlc AND j.entity = l.entity AND j.record_id = l.record_id AND j.field = l.field '
        'WHERE l.entity = ? AND l.field = ? '
        'ON CONFLICT (id) DO UPDATE SET $column = excluded.$column',
        [entity, field],
      );
    }
    await _db.customStatement('DROP TABLE temp.latest');
  }

  // ------------------------------------------------------------ exchange

  /// SQL expression of the origin device of the entry of a journal row.
  static const _originSql = 'substr(hlc, ${Hlc.originOffset + 1})';

  /// For each origin device, the latest timestamp this journal holds.
  Future<KnownState> knownState() async {
    final rows = await _db
        .customSelect('SELECT $_originSql AS origin, MAX(hlc) AS hlc FROM journal GROUP BY origin')
        .get();
    return KnownState({for (final row in rows) row.read<String>('origin'): Hlc.parse(row.read<String>('hlc'))});
  }

  /// The entries a copy with the [known] state lacks, oldest first: about
  /// [limit] of them, at most about [maxBytes] once encoded, never cutting a
  /// modification (a single modification larger than that goes whole).
  Future<JournalPage> missingFrom(KnownState known, {int limit = 500, int maxBytes = 4 << 20}) async {
    final rows = await _missing(known, limit: limit + 1);
    var count = rows.length;
    var size = 0;
    for (var i = 0; i < rows.length; i++) {
      size += _sizeOf(rows[i]);
      if (i == limit || size > maxBytes) {
        count = i;
        break;
      }
    }
    var entries = rows;
    final more = count < rows.length;
    if (more) {
      // rows[count] is the first entry left out: the entries of its
      // modification that made it in are left out too.
      final cut = rows[count].hlc;
      while (count > 0 && rows[count - 1].hlc == cut) {
        count--;
      }
      entries = count > 0 ? rows.sublist(0, count) : await _modification(cut);
    }
    return JournalPage(entries, since: known.only({for (final e in entries) e.deviceId}), more: more);
  }

  /// The number of modifications this journal holds that a copy with the
  /// [known] state lacks: for the server's state, the modifications waiting
  /// to be sent.
  Future<int> pendingFor(KnownState known) async {
    final (where, variables) = await _missingCondition(known);
    final row = await _db
        .customSelect('SELECT COUNT(DISTINCT hlc) AS n FROM journal WHERE $where', variables: variables)
        .getSingle();
    return row.read<int>('n');
  }

  /// Integrates a [page] received from another copy, in one operation:
  /// either every entry is stored and applied, or none is. The page must
  /// continue from what this journal holds ([JournalPage.since]); otherwise
  /// integrating it would leave a gap, and [JournalGapException] is thrown
  /// with nothing written. Returns how many entries were new.
  Future<int> integrate(JournalPage page) => _db.transaction(() async {
    if (page.entries.isEmpty) return 0;
    final held = await knownState();
    for (final origin in {for (final e in page.entries) e.deviceId}) {
      final since = page.since.latest[origin];
      if (since != null && !held.holds(since)) throw JournalGapException(origin);
    }
    return _merge(page.entries);
  });

  /// The condition selecting the entries a copy with [known] lacks. They are
  /// all after the lowest of its timestamps, unless it lacks an origin this
  /// journal holds: the bound lets SQLite skip what both hold.
  Future<(String, List<Variable<Object>>)> _missingCondition(KnownState known) async {
    final held = await knownState();
    var lower = '';
    if (held.origins.isNotEmpty && held.origins.every(known.latest.containsKey)) {
      lower = held.origins.map((o) => known.latest[o]!).reduce((a, b) => a.compareTo(b) <= 0 ? a : b).encode();
    }
    return (
      'hlc > ? AND NOT EXISTS (SELECT 1 FROM json_each(?) k WHERE k.key = $_originSql AND hlc <= k.value)',
      <Variable<Object>>[Variable.withString(lower), Variable.withString(jsonEncode(known.toJson()))],
    );
  }

  Future<List<JournalEntry>> _missing(KnownState known, {required int limit}) async {
    final (where, variables) = await _missingCondition(known);
    final rows = await _db
        .customSelect(
          'SELECT * FROM journal WHERE $where ORDER BY hlc, entity, record_id, field LIMIT ?',
          variables: [...variables, Variable.withInt(limit)],
          readsFrom: {_db.journalEntries},
        )
        .get();
    return [for (final row in rows) _toEntry(_db.journalEntries.map(row.data))];
  }

  Future<List<JournalEntry>> _modification(Hlc hlc) async {
    final rows =
        await (_db.select(_db.journalEntries)
              ..where((j) => j.hlc.equals(hlc.encode()))
              ..orderBy([
                (j) => OrderingTerm.asc(j.entity),
                (j) => OrderingTerm.asc(j.recordId),
                (j) => OrderingTerm.asc(j.field),
              ]))
            .get();
    return rows.map(_toEntry).toList();
  }

  /// About the size of [entry] once encoded in a page.
  static int _sizeOf(JournalEntry entry) =>
      64 +
      entry.hlc.deviceId.length +
      entry.entity.length +
      entry.recordId.length +
      entry.field.length +
      entry.encodedValue.length;

  /// Recomputes every derived table from the journal.
  Future<void> rebuild() => _db.transaction(_rebuildContents);

  Future<void> _rebuildContents() async {
    await _db.delete(_db.fieldVersions).go();
    for (final table in _tables.values) {
      await _db.customStatement('DELETE FROM ${table.table}');
    }
    await _applyLatest(
      'SELECT entity, record_id, field, MAX(hlc) AS hlc FROM journal GROUP BY entity, record_id, field',
    );
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

/// A page continues from more than this journal holds of [origin]:
/// integrating it would leave a gap in that origin's entries.
class JournalGapException implements Exception {
  JournalGapException(this.origin);

  final String origin;

  @override
  String toString() => 'JournalGapException: the page continues from more than is held of $origin';
}
