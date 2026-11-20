import 'package:batz/domain/journal/hlc.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

const a = 'aaaaaaaa-0000-4000-8000-000000000000';
const b = 'bbbbbbbb-0000-4000-8000-000000000000';

void main() {
  test('values are null, bool, int or String', () {
    for (final value in [null, true, 0, -12345, 'text', '']) {
      expect(FieldChange('note', 'r1', 'title', value).value, value);
    }
    expect(() => FieldChange('note', 'r1', 'title', 1.5), throwsArgumentError);
    expect(() => FieldChange('note', 'r1', 'title', <int>[]), throwsArgumentError);
  });

  test('names are checked', () {
    expect(() => FieldChange('Note', 'r1', 'title', 1), throwsArgumentError);
    expect(() => FieldChange('note', '', 'title', 1), throwsArgumentError);
    expect(() => FieldChange('note', 'r1', 'ti tle', 1), throwsArgumentError);
    expect(() => FieldChange('note', 'r1', '_other', 1), throwsArgumentError);
    expect(() => FieldChange('note', 'r1', deletedField, 'yes'), throwsArgumentError);
    expect(FieldChange('note', 'r1', deletedField, true).value, isTrue);
  });

  test('a modification sets each field once', () {
    expect(() => Modification([]), throwsArgumentError);
    expect(
      () => Modification([FieldChange('note', 'r1', 'title', 'a'), FieldChange('note', 'r1', 'title', 'b')]),
      throwsArgumentError,
    );
    final m = Modification.set('note', 'r1', {'title': 'a', 'amount': 3});
    expect(m.changes.map((c) => c.field), ['title', 'amount']);
    expect(Modification.delete('note', 'r1').changes.single.field, deletedField);
  });

  test('values are stored as JSON, keeping their type', () {
    final hlc = Hlc(1, 0, a);
    for (final value in [null, true, false, 1, '1', 'l\'été "chaud"']) {
      final entry = JournalEntry(hlc, FieldChange('note', 'r1', 'title', value));
      expect(JournalEntry.decodeValue(entry.encodedValue), value);
    }
    expect(() => JournalEntry.decodeValue('1.5'), throwsArgumentError);
  });

  test('the latest change wins, the device identifier breaks ties', () {
    expect(supersedes(Hlc(1, 0, a), null), isTrue);
    expect(supersedes(Hlc(2, 0, a), Hlc(1, 0, b)), isTrue);
    expect(supersedes(Hlc(1, 0, a), Hlc(2, 0, b)), isFalse);
    expect(supersedes(Hlc(1, 0, b), Hlc(1, 0, a)), isTrue);
    expect(supersedes(Hlc(1, 0, a), Hlc(1, 0, b)), isFalse);
    expect(supersedes(Hlc(1, 0, a), Hlc(1, 0, a)), isFalse, reason: 'replaying an entry changes nothing');
  });
}
