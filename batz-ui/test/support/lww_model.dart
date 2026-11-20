import 'package:batz/domain/journal/hlc.dart';
import 'package:batz/domain/journal/journal_entry.dart';

/// A deliberately naive, in-memory statement of the resolution rule, used as
/// the oracle the database is checked against: for each field, keep the value
/// of the entry with the greatest timestamp; a record is visible unless its
/// latest deletion value is true.
Map<String, Map<String, Object?>> expectedNotes(Iterable<JournalEntry> entries) {
  final latest = <(String, String), JournalEntry>{};
  for (final e in entries) {
    final key = (e.recordId, e.field);
    final current = latest[key];
    if (current == null || e.hlc.compareTo(current.hlc) > 0) latest[key] = e;
  }
  final records = <String, Map<String, Object?>>{};
  final deleted = <String>{};
  for (final e in latest.values) {
    if (e.field == deletedField) {
      if (e.value == true) deleted.add(e.recordId);
      records.putIfAbsent(e.recordId, () => {'title': null, 'amount': null, 'done': null});
      continue;
    }
    final value = switch (e.value) {
      true => 1,
      false => 0,
      final v => v,
    };
    records.putIfAbsent(e.recordId, () => {'title': null, 'amount': null, 'done': null})[e.field] = value;
  }
  records.removeWhere((id, _) => deleted.contains(id));
  return Map.fromEntries(records.entries.toList()..sort((x, y) => x.key.compareTo(y.key)));
}

Hlc maxHlc(Iterable<Hlc> hlcs) => hlcs.reduce((x, y) => x > y ? x : y);
