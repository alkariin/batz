// Measures the writing of one modification of 1 000 fields, on a database
// file opened in a background isolate as in production, with a journal that
// already holds 20 000 entries. Not part of the regular suite; run it with
//
//   flutter test benchmark/journal_write_test.dart
//
// The result is recorded in docs/decisions.md (step 3.0).
import 'dart:io';

import 'package:batz/data/local/database.dart';
import 'package:batz/data/local/journal.dart';
import 'package:batz/domain/journal/hlc.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _origin = 'aaaaaaaa-0000-4000-8000-000000000000';

/// 100 transactions of 10 fields each, about what an import writes.
Modification _import(int round) => Modification([
  for (var i = 0; i < 100; i++) ...[
    for (final (field, value) in <(String, Object?)>[
      ('accountId', 'account-bank'),
      ('date', '2026-03-${(i % 28 + 1).toString().padLeft(2, '0')}'),
      ('amount', -(100 + i)),
      ('counterpartAccountId', null),
      ('description', 'Commerce n°$i'),
      ('note', 'ACHAT/SERVICE DU 03.03.2026, CARTE NO XXXX0000, Commerce n°$i, Ville'),
      ('status', 'validated'),
    ])
      FieldChange('transaction', 'r$round-t$i', field, value),
    for (final (field, value) in <(String, Object?)>[
      ('transactionId', 'r$round-t$i'),
      ('amount', -(100 + i)),
      ('periodStart', '2026-03-01'),
    ])
      FieldChange('transactionLine', 'r$round-l$i', field, value),
  ],
]);

void main() {
  test('a modification of 1 000 fields', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = Directory.systemTemp.createTempSync('batz-write');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = LocalDatabase(NativeDatabase.createInBackground(File('${dir.path}/batz.db')));
    final journal = await Journal.open(db);
    // A history of 20 000 entries received from another device.
    var millis = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    final history = <JournalEntry>[
      for (var i = 0; i < 2000; i++)
        for (final (field, value) in <(String, Object?)>[
          ('accountId', 'account-cash'),
          ('date', '2026-01-15'),
          ('amount', -(100 + i)),
          ('counterpartAccountId', null),
          ('description', 'Achat n°$i'),
          ('note', ''),
          ('status', 'validated'),
          ('transactionId', null),
          ('categoryId', null),
          ('periodEnd', null),
        ])
          JournalEntry(
            Hlc(millis += 1000, 0, _origin),
            FieldChange(
              field.startsWith('transactionId') || field.startsWith('categoryId') || field == 'periodEnd'
                  ? 'transactionLine'
                  : 'transaction',
              'h$i',
              field,
              value,
            ),
          ),
    ];
    await journal.merge(history);

    final times = <int>[];
    for (var round = 0; round < 5; round++) {
      final watch = Stopwatch()..start();
      await journal.write(_import(round));
      times.add(watch.elapsedMilliseconds);
    }
    // Writing the same values again changes nothing: only the comparison.
    final watch = Stopwatch()..start();
    expect(await journal.write(_import(0)), isNull);
    final unchanged = watch.elapsedMilliseconds;
    // ignore: avoid_print
    print('1 000 fields: ${times.join(', ')} ms; unchanged: $unchanged ms');
    expect(await journal.entries(), hasLength(20000 + 5 * 1000));
    await db.close();
  });
}
