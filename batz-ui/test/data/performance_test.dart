import 'dart:io';

import 'package:batz/data/ledger/ledger_repository.dart';
import 'package:batz/data/local/database.dart';
import 'package:batz/data/local/journal.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/export/export_archive.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/ledger/refund.dart';
import 'package:batz/domain/modules/electricity.dart';
import 'package:batz/domain/modules/flow.dart';
import 'package:batz/domain/modules/salary.dart';
import 'package:batz/domain/modules/subscriptions.dart';
import 'package:batz/domain/modules/taxes.dart';
import 'package:batz/domain/modules/vacations.dart';
import 'package:batz/domain/views/share_operations.dart';
import 'package:batz/domain/views/wealth.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:batz/version.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/large_ledger.dart';
import '../support/machine_lock.dart';

/// The limits of the app: with 10 000 transactions over five years, 12
/// accounts, 100 declared balances, 200 debts and the data of the modules, the
/// screens reload in less than 300 ms after a write, both views of a year are
/// computed in less than 100 ms, and so are the « Fortune » screen, each screen
/// of a module and the flow diagram. Measured on the development machine in
/// docs/decisions.md, « Reference measures ».
///
/// Every one of ten runs must stay below its limit; all are printed. The
/// suite runs its test files concurrently: the whole test, its data written
/// then measured, runs while no other test file runs ([MachineLock]), the
/// servers of the end-to-end files and the screens of the others taking the
/// processors and the memory of the machine (waiting for the lock, the data
/// written before could be swapped out).
void main() {
  test('with 10 000 transactions over five years, 200 rules, 12 accounts, 100 balances, 200 debts and the data of '
      'the modules, the ledger reloads after a write in less than 300 ms, and both views of a year, the « Fortune » '
      'screen, each screen of a module and the flow diagram are computed in less than 100 ms, and the export is made in '
      'less than 2 seconds', () async {
    await MachineLock.exclusive(() async {
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
      expect(ledger.transactions.length, greaterThanOrEqualTo(10000));
      expect(ledger.modules.subscriptions, hasLength(LargeLedger.subscriptions));
      expect(ledger.modules.taxYears, hasLength(LargeLedger.years));
      expect(ledger.rules, hasLength(200));
      expect(ledger.trees.keys, hasLength(5));
      expect(ledger.linesToValidate, hasLength(LargeLedger.linesPerStatement));
      expect(ledger.accounts, hasLength(12));
      expect(ledger.declaredBalances, hasLength(100));
      expect(ledger.debts, hasLength(LargeLedger.debts));
      _tasks(ledger);

      // What every screen needs after a write: the database read, the ledger
      // built, the proposals of the lines to validate, the tasks (shares to
      // classify included, which go through the views of every year) and
      // the key figures of the home screen.
      final reloads = <int>[], writes = <int>[];
      for (var run = 0; run < 10; run++) {
        final line = ledger.linesToValidate[run];
        final write = Stopwatch()..start();
        await repository.write(ledger.updateImportedDetails(line.id, description: 'Achat $run', note: 'note $run'));
        writes.add(write.elapsedMilliseconds);
        final reload = Stopwatch()..start();
        ledger = await repository.load();
        _tasks(ledger);
        reloads.add(reload.elapsedMilliseconds);
      }
      expect(ledger.transactions[ledger.linesToValidate[9].id]!.note, 'note 9');
      // ignore: avoid_print
      print('write: $writes ms; reload: $reloads ms');

      // Both views of a year, on a ledger just loaded: nothing computed yet.
      final computations = <int>[];
      for (var run = 0; run < 10; run++) {
        final fresh = await repository.load();
        final watch = Stopwatch()..start();
        final cash = fresh.views.of(LargeLedger.lastYear, ViewKind.cash)!;
        final economic = fresh.views.of(LargeLedger.lastYear, ViewKind.economic)!;
        computations.add(watch.elapsedMilliseconds);
        expect(cash.savings.total, economic.savings.total + economic.paidForOtherYears - economic.paidInOtherYears);
        expect(economic.paidInOtherYears, isNot(0));
        expect(economic.redistributions, hasLength(4));
      }
      // ignore: avoid_print
      print('both views of a year: $computations ms');

      // The « Fortune » screen, on a ledger just loaded: the accounts and
      // their balances, the curve of the sixty months and more, the table of
      // a year.
      final screens = <int>[];
      for (var run = 0; run < 10; run++) {
        final fresh = await repository.load();
        final watch = Stopwatch()..start();
        final wealth = fresh.wealth(_today);
        final accounts = wealth.at(_today);
        final curve = wealth.monthly;
        final table = wealth.explain(LargeLedger.lastYear);
        screens.add(watch.elapsedMilliseconds);
        expect(accounts.accounts.where((a) => a.inWealth), hasLength(LargeLedger.declaredAccounts.length + 1));
        expect(curve.length, greaterThanOrEqualTo(60));
        expect(table.explained, table.wealthChange);
        expect(table.valueVariations, hasLength(LargeLedger.declaredAccounts.length));
      }
      // ignore: avoid_print
      print('« Fortune » screen: $screens ms');

      // Each screen of a module and the diagram, on a ledger just loaded:
      // the modules are computed when their screen opens.
      final modules = <String, void Function(Ledger ledger)>{
        'salary': (l) {
          expect(l.salarySheet(LargeLedger.lastYear)!.gap, 0);
          expect(l.proposedDeductionLabels(LargeLedger.lastYear + 1), hasLength(3));
        },
        'taxes': (l) {
          for (final year in l.taxYears) {
            final result = l.taxYear(year);
            expect((result.total, result.paid, result.shareOfGross), isNot((0, null, null)));
          }
        },
        'vacations': (l) {
          final vacations = l.vacations;
          expect(vacations.lines, hasLength(LargeLedger.vacationLines));
          for (final year in vacations.years) {
            expect(vacations.totalOf(year), greaterThan(0));
          }
        },
        'electricity': (l) {
          final years = l.electricityYears(currentYear: _today.year);
          expect(years, hasLength(LargeLedger.years));
          for (final year in years) {
            expect(l.electricityYear(year).pricePerKwh, isNotNull);
          }
        },
        'subscriptions': (l) => expect(l.subscriptionsAt(_today).monthlyTotal, greaterThan(0)),
        'diagram': (l) {
          final diagram = flowDiagram(l, LargeLedger.lastYear, ViewKind.economic)!;
          expect((diagram.fromGross, diagram.leftTotal), (true, diagram.rightTotal));
        },
      };
      final moduleTimes = <String, List<int>>{};
      for (final MapEntry(key: name, value: compute) in modules.entries) {
        for (var run = 0; run < 10; run++) {
          final fresh = await repository.load();
          final watch = Stopwatch()..start();
          compute(fresh);
          (moduleTimes[name] ??= []).add(watch.elapsedMilliseconds);
        }
      }
      // ignore: avoid_print
      print('modules: $moduleTimes ms');

      // The export, its twenty-one files and its ZIP, on a ledger just
      // loaded.
      final exports = <int>[];
      for (var run = 0; run < 10; run++) {
        final fresh = await repository.load();
        final watch = Stopwatch()..start();
        final archive = buildExportArchive(fresh, date: _today, appVersion: appVersion);
        exports.add(watch.elapsedMilliseconds);
        expect((archive.csvFiles, archive.transactions), (21, fresh.transactions.length));
      }
      // ignore: avoid_print
      print('export: $exports ms');

      expect(reloads, everyElement(lessThan(300)), reason: 'every reload after a write');
      expect(computations, everyElement(lessThan(100)), reason: 'both views of a year, every time');
      expect(screens, everyElement(lessThan(100)), reason: 'the « Fortune » screen, every time');
      for (final MapEntry(key: name, value: times) in moduleTimes.entries) {
        expect(times, everyElement(lessThan(100)), reason: 'the screen of $name, every time');
      }
      expect(exports, everyElement(lessThan(2000)), reason: 'the export, every time');
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}

/// The day the data are seen: the end of their last year.
final _today = CalendarDate(LargeLedger.lastYear, 12, 31);

/// Reads what the home screen and the navigation show: the tasks, the
/// shares to classify and the old balances among them, and the key figures
/// of the year, the net wealth included.
void _tasks(Ledger ledger) {
  expect(ledger.views.of(LargeLedger.lastYear, ViewKind.economic)!.savings.total, isNot(0));
  final wealth = ledger.wealth(_today);
  expect(wealth.fortuneAt(_today), isNot(0));
  expect(wealth.oldBalances, isEmpty);
  expect(ledger.proposals, hasLength(LargeLedger.linesPerStatement));
  expect(ledger.issues, isEmpty);
  expect(ledger.unusableRules, isEmpty);
  expect(ledger.conflictingLines, 0);
  expect(ledger.refundsByExpenseLine, hasLength(LargeLedger.refunds));
  expect(ledger.brokenRefunds, isEmpty);
  expect(ledger.inapplicableRedistributions, isEmpty);
  expect(ledger.pendingShareCount, greaterThan(0));
  expect(ledger.shareClassifications, isNotEmpty);
}
