import 'dart:convert';

import 'hlc.dart';

final _namePattern = RegExp(r'^[a-z][a-zA-Z0-9]*$');

/// The reserved field that records a deletion. A record is deleted when the
/// latest value of this field is `true`; a deletion is a change like any other
/// (specification, chapter 5).
const deletedField = '_deleted';

/// Checks that [value] can be stored in the journal: null, bool, int or
/// String. Amounts are integer cents, so no floating point is needed.
void checkJournalValue(Object? value) {
  if (value == null || value is bool || value is int || value is String) return;
  throw ArgumentError.value(value, 'value', 'must be null, bool, int or String');
}

/// One field of one record set to one value: the unit of the journal and of
/// conflict resolution.
class FieldChange {
  FieldChange(this.entity, this.recordId, this.field, this.value) {
    if (!_namePattern.hasMatch(entity)) throw ArgumentError.value(entity, 'entity');
    if (recordId.isEmpty) throw ArgumentError.value(recordId, 'recordId');
    if (field != deletedField && !_namePattern.hasMatch(field)) throw ArgumentError.value(field, 'field');
    if (field == deletedField && value is! bool) throw ArgumentError.value(value, 'value', 'deletion is a bool');
    checkJournalValue(value);
  }

  final String entity;
  final String recordId;
  final String field;
  final Object? value;

  @override
  String toString() => '$entity/$recordId.$field = $value';
}

/// A user modification: changes applied together, in a single operation, or
/// not at all. All its entries share one timestamp.
class Modification {
  Modification(Iterable<FieldChange> changes) : changes = List.unmodifiable(changes) {
    if (this.changes.isEmpty) throw ArgumentError('A modification needs at least one change');
    final seen = <(String, String, String)>{};
    for (final c in this.changes) {
      if (!seen.add((c.entity, c.recordId, c.field))) {
        throw ArgumentError('Field set twice in one modification: ${c.entity}/${c.recordId}.${c.field}');
      }
    }
  }

  /// Sets several fields of one record.
  factory Modification.set(String entity, String recordId, Map<String, Object?> fields) =>
      Modification([for (final e in fields.entries) FieldChange(entity, recordId, e.key, e.value)]);

  /// Deletes one record.
  factory Modification.delete(String entity, String recordId) =>
      Modification([FieldChange(entity, recordId, deletedField, true)]);

  final List<FieldChange> changes;
}

/// A change as stored in the journal: what changed, when, on which device.
class JournalEntry {
  JournalEntry(this.hlc, this.change);

  final Hlc hlc;
  final FieldChange change;

  String get entity => change.entity;
  String get recordId => change.recordId;
  String get field => change.field;
  Object? get value => change.value;

  /// The device that made the change.
  String get deviceId => hlc.deviceId;

  /// The value as stored in the journal: JSON, so that `1` and `"1"` differ.
  String get encodedValue => jsonEncode(value);

  static Object? decodeValue(String encoded) {
    final value = jsonDecode(encoded);
    checkJournalValue(value);
    return value;
  }

  @override
  String toString() => '$hlc $change';
}

/// The resolution rule: field by field, the latest change wins
/// (specification, chapter 5). Timestamps of two devices never tie, the
/// device identifier deciding; replaying the same entry changes nothing.
bool supersedes(Hlc incoming, Hlc? current) => current == null || incoming > current;
