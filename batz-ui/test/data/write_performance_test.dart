import 'dart:io';

import 'package:batz/data/ledger/ledger_repository.dart';
import 'package:batz/data/local/database.dart';
import 'package:batz/data/local/journal.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A device as in production: a database file in a background isolate.
Future<(LocalDatabase, LedgerRepository)> _device(Directory dir) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = LocalDatabase(NativeDatabase.createInBackground(File('${dir.path}/batz.db')));
  final journal = await Journal.open(db);
  return (db, LedgerRepository(db, journal));
}

ExtractedStatement _statement(int lines) => ExtractedStatement(
  format: 'postfinance',
  iban: 'CH0090000000123456789',
  currency: 'CHF',
  periodStart: CalendarDate(2026, 1, 1),
  periodEnd: CalendarDate(2026, 1, 31),
  openingBalance: 1000000,
  closingBalance: 1000000 - lines * 1250,
  totalCredits: 0,
  totalDebits: lines * 1250,
  lines: [
    for (var i = 0; i < lines; i++)
      ExtractedLine(
        date: CalendarDate(2026, 1, 1 + i % 28),
        amount: -1250,
        rawText: 'ACHAT/SERVICE DU 01.01.2026\nCARTE NO XXXX0000\nCommerce n°$i\nFictiville',
        label: 'Commerce n°$i Fictiville',
      ),
  ],
);

void main() {
  // An import of 100 lines is written in less than a second. Measured on the
  // development machine in docs/decisions.md, « Reference measures », as the
  // next one.
  test('the import of a statement of 100 lines is written in less than a second', () async {
    final dir = Directory.systemTemp.createTempSync('batz-perf');
    addTearDown(() => dir.deleteSync(recursive: true));
    final (db, repository) = await _device(dir);
    await repository.write(
      (await repository.load()).createAccount(
        'bank',
        const AccountDraft(
          name: 'PostFinance',
          type: AccountType.privateAccount,
          importFormat: ImportFormat.postfinance,
        ),
      ),
    );
    final import = (await repository.load()).importStatement('bank', _statement(100), fingerprint: 'a' * 64);
    final watch = Stopwatch()..start();
    await repository.write(import.modification);
    final elapsed = watch.elapsedMilliseconds;
    // ignore: avoid_print
    print('import of 100 lines (${import.modification.changes.length} fields): $elapsed ms');
    expect(elapsed, lessThan(1000));
    expect((await repository.load()).linesOf(import.statementId), hasLength(100));
    await db.close();
  });

  // The confirmation of 500 proposals is written in less than a second.
  test('the confirmation of 500 proposals is written in less than a second', () async {
    final dir = Directory.systemTemp.createTempSync('batz-perf');
    addTearDown(() => dir.deleteSync(recursive: true));
    final (db, repository) = await _device(dir);
    await repository.write(
      (await repository.load()).createAccount(
        'bank',
        const AccountDraft(
          name: 'PostFinance',
          type: AccountType.privateAccount,
          importFormat: ImportFormat.postfinance,
        ),
      ),
    );
    final import = (await repository.load()).importStatement('bank', _statement(500), fingerprint: 'b' * 64);
    await repository.write(import.modification);
    var ledger = await repository.load();
    await repository.write(
      ledger.addCategory(
        'food',
        year: 2026,
        name: 'Nourriture',
        parentId: defaultGroupId(2026, CategoryNature.expense),
      ),
    );
    await repository.write(
      (await repository.load()).createRule(
        'rule',
        const RuleDraft(year: 2026, lines: ['commerce ET fictiville'], targetCategoryId: 'food'),
      ),
    );
    ledger = await repository.load();
    final modifications = ledger.confirmProposals([for (final t in ledger.linesToValidate) t.id]);
    expect(modifications, hasLength(1));
    final watch = Stopwatch()..start();
    await repository.write(modifications.single);
    final elapsed = watch.elapsedMilliseconds;
    // ignore: avoid_print
    print('confirmation of 500 proposals (${modifications.single.changes.length} fields): $elapsed ms');
    expect(elapsed, lessThan(1000));
    expect((await repository.load()).linesToValidate, isEmpty);
    await db.close();
  });
}
