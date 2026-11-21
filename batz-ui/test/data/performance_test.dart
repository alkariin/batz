import 'dart:io';
import 'dart:math';

import 'package:batz/data/ledger/ledger_repository.dart';
import 'package:batz/data/local/database.dart';
import 'package:batz/data/local/journal.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/refund.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/large_ledger.dart';

/// Acceptance criterion of phase 4: with 10 000 transactions over five years,
/// the screens reload in less than 300 ms after a write, and both views of a
/// year are computed in less than 100 ms. Measured on the development machine
/// in docs/decisions.md (steps 4.0 and 4.1).
///
/// The suite runs its test files concurrently: each figure is the best of
/// five runs, so that another file busy at the same moment does not decide
/// the outcome. Every run is printed.
void main() {
  test('with 10 000 transactions over five years and 200 rules, the ledger reloads after a write in less than '
      '300 ms, and both views of a year are computed in less than 100 ms', () async {
    final dir = Directory.systemTemp.createTempSync('batz-perf');
    addTearDown(() => dir.deleteSync(recursive: true));
    // A device as in production: a database file in a background isolate.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = LocalDatabase(NativeDatabase.createInBackground(File('${dir.path}/batz.db')));
    addTearDown(db.close);
    final repository = LedgerRepository(db, await Journal.open(db));

    final setup = Stopwatch()..start();
    await LargeLedger.write(repository);
    var ledger = await repository.load();
    // ignore: avoid_print
    print('data written in ${setup.elapsedMilliseconds} ms');
    expect(ledger.transactions, hasLength(LargeLedger.transactions));
    expect(ledger.transactions, hasLength(10000));
    expect(ledger.rules, hasLength(200));
    expect(ledger.trees.keys, hasLength(5));
    expect(ledger.linesToValidate, hasLength(LargeLedger.linesPerStatement));

    // What every screen needs after a write: the database read, the ledger
    // built, the proposals of the lines to validate, the tasks.
    final reloads = <int>[], writes = <int>[];
    for (var run = 0; run < 5; run++) {
      final line = ledger.linesToValidate[run];
      final write = Stopwatch()..start();
      await repository.write(ledger.updateImportedDetails(line.id, description: 'Achat $run', note: 'note $run'));
      writes.add(write.elapsedMilliseconds);
      final reload = Stopwatch()..start();
      ledger = await repository.load();
      _tasks(ledger);
      reloads.add(reload.elapsedMilliseconds);
    }
    expect(ledger.transactions[ledger.linesToValidate[4].id]!.note, 'note 4');
    // ignore: avoid_print
    print('write: $writes ms; reload: $reloads ms');
    expect(reloads.reduce(min), lessThan(300));

    // Both views of a year, on a ledger just loaded: nothing computed yet.
    final computations = <int>[];
    for (var run = 0; run < 5; run++) {
      final fresh = await repository.load();
      final watch = Stopwatch()..start();
      final cash = fresh.views.of(2028, ViewKind.cash)!;
      final economic = fresh.views.of(2028, ViewKind.economic)!;
      computations.add(watch.elapsedMilliseconds);
      expect(cash.savings.total, economic.savings.total + economic.paidForOtherYears - economic.paidInOtherYears);
      expect(economic.paidInOtherYears, isNot(0));
      expect(economic.redistributions, hasLength(4));
    }
    // ignore: avoid_print
    print('both views of a year: $computations ms');
    expect(computations.reduce(min), lessThan(100));
  }, timeout: const Timeout(Duration(minutes: 3)));
}

/// Reads what the home screen and the navigation show.
void _tasks(Ledger ledger) {
  expect(ledger.proposals, hasLength(LargeLedger.linesPerStatement));
  expect(ledger.issues, isEmpty);
  expect(ledger.unusableRules, isEmpty);
  expect(ledger.conflictingLines, 0);
  expect(ledger.refundsByExpenseLine, hasLength(LargeLedger.refunds));
  expect(ledger.brokenRefunds, isEmpty);
}
