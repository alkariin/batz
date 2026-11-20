import 'dart:io';
import 'dart:math';

import 'package:batz/data/local/derived_tables.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/journal_harness.dart';
import '../support/lww_model.dart';

const me = '11111111-0000-4000-8000-000000000000';
const other = '22222222-0000-4000-8000-000000000000';
const third = '33333333-0000-4000-8000-000000000000';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('batz-journal'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('writing', () {
    test('a modification is journaled and applied in one go', () async {
      final h = await Harness.open(now: () => 1000, deviceId: me);
      final hlc = await h.journal.write(
        Modification.set('note', 'n1', {'title': 'Loyer', 'amount': -150000, 'done': true}),
      );

      expect(await h.notes(), {
        'n1': {'title': 'Loyer', 'amount': -150000, 'done': 1},
      });
      final entries = await h.journal.entries();
      expect(entries, hasLength(3));
      expect(entries.map((e) => e.hlc).toSet(), {hlc}, reason: 'one modification, one timestamp');
      expect(entries.every((e) => e.deviceId == me), isTrue);
      await h.close();
    });

    test('an unknown entity or field is refused before anything is written', () async {
      final h = await Harness.open(deviceId: me);
      await expectLater(
        h.journal.write(Modification.set('note', 'n1', {'title': 'x', 'colour': 'red'})),
        throwsArgumentError,
      );
      await expectLater(h.journal.write(Modification.set('other', 'n1', {'title': 'x'})), throwsArgumentError);
      expect(await h.journal.entries(), isEmpty);
      expect(await h.allRows(), isEmpty);
      await h.close();
    });

    test('a failure half-way leaves neither journal entries nor derived rows', () async {
      // "broken" maps to a column that does not exist: the second statement fails.
      final broken = DerivedTable(
        entity: 'note',
        table: 'notes',
        columns: {'title': 'title', 'broken': 'no_such_column'},
      );
      final h = await Harness.open(deviceId: me, tables: [broken]);
      await expectLater(
        h.journal.write(Modification.set('note', 'n1', {'title': 'x', 'broken': 1})),
        throwsA(anything),
      );
      expect(await h.journal.entries(), isEmpty);
      expect(await h.allRows(), isEmpty);
      await h.close();
    });

    test('a later write of the same field wins, other fields stay', () async {
      var wall = 1000;
      final h = await Harness.open(now: () => wall, deviceId: me);
      await h.journal.write(Modification.set('note', 'n1', {'title': 'A', 'amount': 1}));
      wall = 2000;
      await h.journal.write(Modification.set('note', 'n1', {'title': 'B'}));
      expect(await h.notes(), {
        'n1': {'title': 'B', 'amount': 1, 'done': null},
      });
      await h.close();
    });

    test('several writes in the same millisecond keep their order', () async {
      final h = await Harness.open(now: () => 1000, deviceId: me);
      for (final title in ['1', '2', '3']) {
        await h.journal.write(Modification.set('note', 'n1', {'title': title}));
      }
      expect((await h.notes())['n1']!['title'], '3');
      await h.close();
    });
  });

  group('order', () {
    test('field by field: concurrent edits of different fields are both kept', () async {
      final h = await Harness.open(now: () => 1000, deviceId: me);
      await h.journal.write(Modification.set('note', 'n1', {'title': 'Mine'}));
      await h.journal.merge([entry(1000, 5, other, 'n1', 'amount', 4200)]);
      expect(await h.notes(), {
        'n1': {'title': 'Mine', 'amount': 4200, 'done': null},
      });
      await h.close();
    });

    test('an older change arriving late does not overwrite a newer one', () async {
      final h = await Harness.open(now: () => 5000, deviceId: me);
      await h.journal.write(Modification.set('note', 'n1', {'title': 'New'}));
      final added = await h.journal.merge([entry(4000, 0, other, 'n1', 'title', 'Old')]);
      expect(added, 1, reason: 'the entry is kept in the journal');
      expect((await h.notes())['n1']!['title'], 'New');
      await h.close();
    });

    test('a newer change from another device replaces the local one', () async {
      final h = await Harness.open(now: () => 5000, deviceId: me);
      await h.journal.write(Modification.set('note', 'n1', {'title': 'Mine'}));
      await h.journal.merge([entry(6000, 0, other, 'n1', 'title', 'Theirs')]);
      expect((await h.notes())['n1']!['title'], 'Theirs');
      await h.close();
    });

    test('after seeing a timestamp from the future, local writes still win over it', () async {
      final h = await Harness.open(now: () => 1000, deviceId: me);
      await h.journal.merge([entry(999999, 0, other, 'n1', 'title', 'Future')]);
      await h.journal.write(Modification.set('note', 'n1', {'title': 'Now'}));
      expect((await h.notes())['n1']!['title'], 'Now');
      await h.close();
    });

    test('the result does not depend on the arrival order (checked against a model)', () async {
      final random = Random(2026);
      for (var round = 0; round < 25; round++) {
        final entries = _randomHistory(random);
        final expected = expectedNotes(entries);
        for (var permutation = 0; permutation < 3; permutation++) {
          final shuffled = [...entries]..shuffle(random);
          final h = await Harness.open(deviceId: me);
          // Arrive in several batches, as successive synchronisations would.
          for (var i = 0; i < shuffled.length; i += 7) {
            await h.journal.merge(shuffled.sublist(i, min(i + 7, shuffled.length)));
          }
          expect(await h.notes(), expected, reason: 'round $round, permutation $permutation');
          await h.close();
        }
      }
    });
  });

  group('ties', () {
    test('same time and counter: the greater device identifier wins, whatever the order', () async {
      final mine = entry(1000, 0, other, 'n1', 'title', 'From 2222');
      final theirs = entry(1000, 0, third, 'n1', 'title', 'From 3333');
      for (final order in [
        [mine, theirs],
        [theirs, mine],
      ]) {
        final h = await Harness.open(deviceId: me);
        await h.journal.merge(order);
        expect((await h.notes())['n1']!['title'], 'From 3333');
        await h.close();
      }
    });

    test('a local write and a remote one in the same millisecond', () async {
      // The local device "1111…" ties with "2222…" on time and counter.
      final h = await Harness.open(now: () => 1000, deviceId: me);
      await h.journal.write(Modification.set('note', 'n1', {'title': 'Local'}));
      await h.journal.merge([entry(1000, 0, other, 'n1', 'title', 'Remote')]);
      expect((await h.notes())['n1']!['title'], 'Remote');
      await h.close();
    });

    test('replaying entries changes nothing', () async {
      final h = await Harness.open(deviceId: me);
      final batch = [entry(1000, 0, other, 'n1', 'title', 'A'), entry(1001, 0, other, 'n1', 'amount', 5)];
      expect(await h.journal.merge(batch), 2);
      final before = await h.allRows();
      expect(await h.journal.merge(batch), 0);
      expect(await h.allRows(), before);
      expect(await h.journal.entries(), hasLength(2));
      await h.close();
    });
  });

  group('deletion', () {
    test('a deletion hides the record and propagates like any change', () async {
      var wall = 1000;
      final h = await Harness.open(now: () => wall, deviceId: me);
      await h.journal.write(Modification.set('note', 'n1', {'title': 'A'}));
      await h.journal.write(Modification.set('note', 'n2', {'title': 'B'}));
      wall = 2000;
      await h.journal.write(Modification.delete('note', 'n1'));
      expect((await h.notes()).keys, ['n2']);

      final replica = await Harness.open(deviceId: other);
      await replica.journal.merge(await h.journal.entries());
      expect((await replica.notes()).keys, ['n2']);
      await h.close();
      await replica.close();
    });

    test('a deletion made offline wins over older edits that arrive later', () async {
      final h = await Harness.open(now: () => 5000, deviceId: me);
      await h.journal.merge([entry(1000, 0, other, 'n1', 'title', 'A')]);
      await h.journal.write(Modification.delete('note', 'n1'));
      await h.journal.merge([entry(3000, 0, other, 'n1', 'title', 'Edited before the deletion')]);
      expect(await h.notes(), isEmpty);
      await h.close();
    });

    test('an edit made after the deletion does not resurrect the record', () async {
      final h = await Harness.open(now: () => 1000, deviceId: me);
      await h.journal.write(Modification.set('note', 'n1', {'title': 'A'}));
      await h.journal.write(Modification.delete('note', 'n1'));
      await h.journal.merge([entry(9000, 0, other, 'n1', 'title', 'Late edit')]);
      expect(await h.notes(), isEmpty);
      await h.close();
    });

    test('an explicit restore after the deletion brings the record back', () async {
      var wall = 1000;
      final h = await Harness.open(now: () => wall, deviceId: me);
      await h.journal.write(Modification.set('note', 'n1', {'title': 'A'}));
      wall = 2000;
      await h.journal.write(Modification.delete('note', 'n1'));
      wall = 3000;
      await h.journal.write(Modification([FieldChange('note', 'n1', deletedField, false)]));
      expect(await h.notes(), {
        'n1': {'title': 'A', 'amount': null, 'done': null},
      });
      await h.close();
    });

    test('deleting a record never seen before still records the deletion', () async {
      final h = await Harness.open(deviceId: me);
      await h.journal.merge([entry(2000, 0, other, 'n1', deletedField, true)]);
      await h.journal.merge([entry(1000, 0, third, 'n1', 'title', 'Created earlier elsewhere')]);
      expect(await h.notes(), isEmpty);
      await h.close();
    });
  });

  group('restart', () {
    test('the device identifier is created on the first launch and kept', () async {
      final file = File('${dir.path}/batz.db');
      final first = await Harness.open(file: file);
      final id = first.journal.deviceId;
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      await first.close();

      final second = await Harness.open(file: file);
      expect(second.journal.deviceId, id);
      await second.close();

      final elsewhere = await Harness.open(file: File('${dir.path}/other.db'));
      expect(elsewhere.journal.deviceId, isNot(id));
      await elsewhere.close();
    });

    test('data and order survive a restart, even with the clock set back', () async {
      final file = File('${dir.path}/batz.db');
      final first = await Harness.open(file: file, now: () => 50000);
      await first.journal.write(Modification.set('note', 'n1', {'title': 'Before restart', 'amount': 1}));
      await first.journal.merge([entry(60000, 3, other, 'n2', 'title', 'Remote')]);
      final lastBefore = maxHlc((await first.journal.entries()).map((e) => e.hlc));
      await first.close();

      // The wall clock now reads earlier than anything in the journal.
      final second = await Harness.open(file: file, now: () => 10);
      expect(await second.notes(), {
        'n1': {'title': 'Before restart', 'amount': 1, 'done': null},
        'n2': {'title': 'Remote', 'amount': null, 'done': null},
      });
      final hlc = await second.journal.write(Modification.set('note', 'n1', {'title': 'After restart'}));
      expect(hlc > lastBefore, isTrue);
      expect((await second.notes())['n1']!['title'], 'After restart');
      await second.close();
    });

    test('a crash before commit leaves the previous state intact', () async {
      final file = File('${dir.path}/batz.db');
      final first = await Harness.open(file: file, now: () => 1000);
      await first.journal.write(Modification.set('note', 'n1', {'title': 'Committed'}));
      // Simulate a crash in the middle of a transaction: the process dies
      // before the commit, which an exception reproduces.
      await expectLater(
        first.db.transaction(() async {
          await first.db.customStatement("UPDATE notes SET title = 'Half-written'");
          throw const FileSystemException('power cut');
        }),
        throwsA(isA<FileSystemException>()),
      );
      await first.close();

      final second = await Harness.open(file: file);
      expect((await second.notes())['n1']!['title'], 'Committed');
      await second.close();
    });
  });

  group('derived tables', () {
    test('a rebuild from the journal gives the same tables', () async {
      final h = await Harness.open(deviceId: me);
      await h.journal.merge(_randomHistory(Random(3)));
      final before = await h.allRows();
      await h.db.customStatement("UPDATE notes SET title = 'corrupted'");
      await h.journal.rebuild();
      expect(await h.allRows(), before);
      await h.close();
    });

    test('entries of an entity unknown to this version are kept, then applied once known', () async {
      final file = File('${dir.path}/batz.db');
      final old = await Harness.open(file: file, deviceId: me, tables: []);
      expect(await old.journal.merge([entry(1000, 0, other, 'n1', 'title', 'From a newer version')]), 1);
      expect(await old.allRows(), isEmpty);
      await old.close();

      final upgraded = await Harness.open(file: file, deviceId: me);
      await upgraded.journal.rebuild();
      expect((await upgraded.notes())['n1']!['title'], 'From a newer version');
      await upgraded.close();
    });

    test('definitions refuse unsafe or reserved identifiers', () {
      expect(() => DerivedTable(entity: 'x', table: 'x; DROP TABLE journal', columns: {}), throwsArgumentError);
      expect(() => DerivedTable(entity: 'x', table: 'x', columns: {'a': 'id'}), throwsArgumentError);
      expect(() => DerivedTable(entity: 'x', table: 'x', columns: {'a': 'deleted'}), throwsArgumentError);
      expect(() => DerivedTable(entity: 'x', table: 'x', columns: {'a': 'A'}), throwsArgumentError);
    });
  });
}

/// A random history on a few records: three devices, close timestamps so that
/// ties on time and counter happen, edits, deletions and restores.
List<JournalEntry> _randomHistory(Random random) {
  const devices = [me, other, third];
  final entries = <JournalEntry>[];
  final used = <String>{};
  while (entries.length < 40) {
    final device = devices[random.nextInt(devices.length)];
    final millis = 1000 + random.nextInt(6);
    final counter = random.nextInt(2);
    final id = 'n${random.nextInt(4)}';
    final roll = random.nextInt(10);
    final (field, value) = switch (roll) {
      0 => (deletedField, true),
      1 => (deletedField, false),
      2 || 3 || 4 => ('title', 't${random.nextInt(100)}'),
      5 || 6 => ('amount', random.nextInt(20000) - 10000),
      7 => ('amount', null),
      _ => ('done', random.nextBool()),
    };
    // One device never emits two values for the same field at the same time.
    if (!used.add('$device $millis $counter $id $field')) continue;
    entries.add(entry(millis, counter, device, id, field, value));
  }
  return entries;
}
