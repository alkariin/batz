import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/statements.dart';

final january = fixtureStatement('2026-01');
final february = fixtureStatement('2026-02');
final march = fixtureStatement('2026-03');
final otherAccount = fixtureStatement('other-account-2026-04');

/// Imports [fixture] into the detailed account `bank`.
Future<StatementImport> import(LedgerHarness h, FixtureStatement fixture) async {
  final result = (await h.ledger()).importStatement('bank', fixture.statement, fingerprint: fixture.fingerprint);
  await h.repository.write(result.modification);
  return result;
}

/// The refusal of importing [fixture], with the journal checked unchanged.
Future<StatementRefusedException> refusal(LedgerHarness h, FixtureStatement fixture, {String account = 'bank'}) async {
  final before = await h.journal.entries();
  final ledger = await h.ledger();
  late StatementRefusedException refused;
  expect(
    () => ledger.importStatement(account, fixture.statement, fingerprint: fixture.fingerprint),
    throwsA(isA<StatementRefusedException>().having((e) => refused = e, 'refusal', anything)),
  );
  expect((await h.journal.entries()).length, before.length, reason: 'nothing written');
  return refused;
}

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
  });
  tearDown(() => h.close());

  test('the fictitious statements are imported one after the other, their lines to validate', () async {
    final first = await import(h, january);
    expect(first.first, isTrue, reason: 'the first statement of the account');
    var ledger = await h.ledger();
    final statement = ledger.statements[first.statementId]!;
    expect(statement.id, statementId('bank', january.fingerprint));
    expect(
      (statement.accountId, statement.iban, statement.periodStart, statement.periodEnd),
      ('bank', 'CH0090000000123456789', CalendarDate(2026, 1, 1), CalendarDate(2026, 1, 31)),
    );
    expect((statement.openingBalance, statement.closingBalance), (234567, 499022));
    expect(statement.fingerprint, january.fingerprint);

    final lines = ledger.linesOf(statement.id);
    expect(lines, hasLength(27));
    for (final (rank, t) in lines.indexed) {
      final line = january.statement.lines[rank];
      expect(t.id, importedTransactionId(statement.id, rank));
      expect((t.accountId, t.date, t.amount), ('bank', line.date, line.amount));
      expect(t.rawText, line.rawText);
      expect(t.description, line.label, reason: 'the short label');
      expect((t.status, t.statementId, t.statementRank), (TransactionStatus.toValidate, statement.id, rank));
      expect((t.counterpartAccountId, t.note), (null, ''));
      expect(t.lines, isEmpty);
    }
    expect(lines.first.rawText, 'DÉBIT\nCH0000000000000000001\nGérance Imaginaire SA\nRue du Bail 3\n9999 Fictiville');
    expect(lines.first.description, 'Gérance Imaginaire SA Rue du Bail 3 9999 Fictiville');

    expect((await import(h, february)).first, isFalse);
    await import(h, march);
    ledger = await h.ledger();
    expect(ledger.statementsOf('bank').map((s) => s.periodStart.month), [1, 2, 3]);
    expect(ledger.statementsOf('bank').map((s) => ledger.linesOf(s.id).length), [27, 21, 12]);
  });

  test(
    'the balances computed from the imported lines are the printed ones, at each balance of the statements',
    () async {
      for (final f in [january, february, march]) {
        await import(h, f);
      }
      final ledger = await h.ledger();
      var balance = ledger.statementsOf('bank').first.openingBalance;
      var printed = 0;
      for (final statement in ledger.statementsOf('bank')) {
        expect(statement.openingBalance, balance);
        final extracted = [
          january,
          february,
          march,
        ].firstWhere((f) => f.fingerprint == statement.fingerprint).statement;
        for (final (rank, t) in ledger.linesOf(statement.id).indexed) {
          balance += t.amount;
          if (extracted.lines[rank].balance case final expected?) {
            expect(balance, expected, reason: '${statement.periodStart} line $rank');
            printed++;
          }
        }
        expect(balance, statement.closingBalance);
      }
      expect(printed, greaterThan(30));
    },
  );

  test('a statement already imported is refused, from the journal', () async {
    await import(h, january);
    expect((await refusal(h, january)).error, LedgerError.statementAlreadyImported);
  });

  test('a statement that does not follow the previous one is refused, with what was expected and found', () async {
    await import(h, january);
    final refused = await refusal(h, march);
    expect(refused.error, LedgerError.statementNotContiguous);
    expect((refused.expectedStart, refused.foundStart), (CalendarDate(2026, 2, 1), CalendarDate(2026, 3, 1)));
    expect((refused.expectedOpening, refused.foundOpening), (499022, march.statement.openingBalance));

    // An earlier statement can no longer be imported once a later one is.
    await import(h, february);
    await import(h, march);
    final h2 = await LedgerHarness.open();
    await seedLedger(h2);
    await import(h2, february);
    expect((await refusal(h2, january)).error, LedgerError.statementNotContiguous);
    await h2.close();
  });

  test('a statement whose opening balance differs from the previous closing balance is refused', () async {
    await import(h, january);
    final shifted = ExtractedStatement(
      format: 'postfinance',
      iban: february.statement.iban,
      currency: 'CHF',
      periodStart: february.statement.periodStart,
      periodEnd: february.statement.periodEnd,
      openingBalance: february.statement.openingBalance + 100,
      closingBalance: february.statement.closingBalance + 100,
      totalCredits: february.statement.totalCredits,
      totalDebits: february.statement.totalDebits,
      lines: february.statement.lines,
    );
    final refused = await refusal(h, FixtureStatement('shifted', shifted, 'f' * 64, const []));
    expect(refused.error, LedgerError.statementNotContiguous);
    expect((refused.expectedStart, refused.foundStart), (CalendarDate(2026, 2, 1), CalendarDate(2026, 2, 1)));
    expect((refused.expectedOpening, refused.foundOpening), (499022, 499122));
  });

  test("another account's statement is refused, with both IBANs", () async {
    for (final f in [january, february, march]) {
      await import(h, f);
    }
    final refused = await refusal(h, otherAccount);
    expect(refused.error, LedgerError.statementOtherAccount);
    expect((refused.expectedIban, refused.foundIban), ('CH0090000000123456789', 'CH0090000000987654321'));
  });

  test('lines that do not add up to the difference of the balances are refused', () async {
    final s = january.statement;
    final broken = ExtractedStatement(
      format: s.format,
      iban: s.iban,
      currency: s.currency,
      periodStart: s.periodStart,
      periodEnd: s.periodEnd,
      openingBalance: s.openingBalance,
      closingBalance: s.closingBalance + 1,
      totalCredits: s.totalCredits,
      totalDebits: s.totalDebits,
      lines: s.lines,
    );
    expect(
      (await refusal(h, FixtureStatement('broken', broken, 'e' * 64, const []))).error,
      LedgerError.statementSumMismatch,
    );
  });

  test('only a detailed account, of the format of the statement, takes it', () async {
    expect((await refusal(h, january, account: 'private')).error, LedgerError.accountNotDetailed);
    final s = january.statement;
    final other = ExtractedStatement(
      format: 'otherbank',
      iban: s.iban,
      currency: s.currency,
      periodStart: s.periodStart,
      periodEnd: s.periodEnd,
      openingBalance: s.openingBalance,
      closingBalance: s.closingBalance,
      totalCredits: s.totalCredits,
      totalDebits: s.totalDebits,
      lines: s.lines,
    );
    expect(
      (await refusal(h, FixtureStatement('other', other, 'd' * 64, const []))).error,
      LedgerError.statementOtherFormat,
    );
  });

  test('a statement too large for one modification is refused', () async {
    final s = january.statement;
    final lines = [
      for (var i = 0; i < 1300; i++)
        ExtractedLine(date: CalendarDate(2026, 1, 2), amount: -1, rawText: 'DÉBIT\nLigne $i', label: 'Ligne $i'),
    ];
    final huge = ExtractedStatement(
      format: s.format,
      iban: s.iban,
      currency: s.currency,
      periodStart: s.periodStart,
      periodEnd: s.periodEnd,
      openingBalance: 0,
      closingBalance: -1300,
      totalCredits: 0,
      totalDebits: 1300,
      lines: lines,
    );
    expect((await refusal(h, FixtureStatement('huge', huge, 'c' * 64, const []))).error, LedgerError.statementTooLarge);
  });

  test('on the detailed account, amount, date and text cannot change, no line is entered or deleted', () async {
    await import(h, january);
    final ledger = await h.ledger();
    final t = ledger.linesOf(statementId('bank', january.fingerprint)).first;

    LedgerError? refused(Modification Function() build) {
      try {
        build();
      } on LedgerException catch (e) {
        return e.error;
      }
      return null;
    }

    final changed = EntryDraft(
      accountId: 'bank',
      date: CalendarDate(2026, 1, 6),
      cents: 1,
      direction: Direction.outflow,
      categoryId: 'food',
    );
    expect(refused(() => ledger.updateEntry(t.id, changed)), LedgerError.detailedAccountManual);
    expect(
      refused(() => ledger.updateEntry(t.id, entry(account: 'cash'))),
      LedgerError.detailedAccountManual,
      reason: 'not moved to another account either',
    );
    expect(refused(() => ledger.deleteTransaction(t.id)), LedgerError.detailedAccountManual);
    expect(
      refused(() => ledger.recordEntry('new', 'new-line', entry(account: 'bank'))),
      LedgerError.detailedAccountManual,
    );
    expect(refused(() => ledger.recordTransfer('new', transfer(from: 'bank'))), LedgerError.detailedAccountManual);
    expect(refused(() => ledger.recordTransfer('new', transfer(to: 'bank'))), LedgerError.detailedAccountManual);
    expect(refused(() => ledger.updateTransfer(t.id, transfer())), LedgerError.detailedAccountManual);

    // Description and note do change; nothing else.
    await h.apply((l) => l.updateImportedDetails(t.id, description: ' Loyer de janvier ', note: 'Payé en avance'));
    final after = (await h.ledger()).transactions[t.id]!;
    expect((after.description, after.note), ('Loyer de janvier', 'Payé en avance'));
    expect((after.amount, after.date, after.rawText, after.accountId), (t.amount, t.date, t.rawText, t.accountId));
    expect(
      refused(() => ledger.updateImportedDetails('food-entry', description: '', note: '')),
      LedgerError.unknownTransaction,
    );
  });

  test('an imported line stays immutable even if import is disabled on its account', () async {
    await import(h, january);
    await h.apply(
      (l) => l.updateAccount('bank', const AccountDraft(name: 'PostFinance', type: AccountType.privateAccount)),
    );
    final ledger = await h.ledger();
    final t = ledger.linesOf(statementId('bank', january.fingerprint)).first;
    expect(
      () => ledger.deleteTransaction(t.id),
      throwsA(isA<LedgerException>().having((e) => e.error, 'error', LedgerError.importedTransaction)),
    );
  });

  test(
    'the last statement is deleted with its lines; an earlier one is not; the deleted one is imported again',
    () async {
      await import(h, january);
      final feb = await import(h, february);
      final janId = statementId('bank', january.fingerprint);
      var ledger = await h.ledger();
      expect(
        () => ledger.deleteLastStatement(janId),
        throwsA(isA<LedgerException>().having((e) => e.error, 'error', LedgerError.statementNotLast)),
      );

      // The user corrects a line of February before deleting it.
      final line = ledger.linesOf(feb.statementId)[3];
      await h.apply((l) => l.updateImportedDetails(line.id, description: 'Corrigé', note: 'Une note'));

      await h.apply((l) => l.deleteLastStatement(feb.statementId));
      ledger = await h.ledger();
      expect(ledger.statements.keys, [janId]);
      expect(ledger.linesOf(feb.statementId), isEmpty);
      expect(ledger.transactions.values.where((t) => t.statementId == feb.statementId), isEmpty);
      expect(ledger.deletedStatementIds, {feb.statementId});
      expect(ledger.lastStatementOf('bank')!.id, janId);

      // Imported again: the same records come back, as imported.
      final again = await import(h, february);
      expect(again.statementId, feb.statementId);
      ledger = await h.ledger();
      expect(ledger.linesOf(feb.statementId), hasLength(21));
      final back = ledger.transactions[line.id]!;
      expect(
        (back.description, back.note, back.status),
        (february.statement.lines[3].label, '', TransactionStatus.toValidate),
      );
      expect(ledger.deletedStatementIds, isEmpty);
    },
  );

  test('a line that opens a year carries the copy of the tree', () async {
    final fresh = await LedgerHarness.open();
    await fresh.apply(
      (l) => l.createAccount(
        'bank',
        const AccountDraft(
          name: 'PostFinance',
          type: AccountType.privateAccount,
          importFormat: ImportFormat.postfinance,
        ),
      ),
    );
    await fresh.apply((l) => l.createTree(2025));
    await fresh.apply(
      (l) => l.addCategory(
        'food-2025',
        year: 2025,
        name: 'Nourriture',
        parentId: defaultGroupId(2025, CategoryNature.expense),
      ),
    );
    await import(fresh, january);
    final ledger = await fresh.ledger();
    expect(ledger.trees[2026]!.named('Nourriture')!.id, copiedCategoryId('food-2025', 2026));
    await fresh.close();
  });

  test('imported lines not classified yet count as unclassified in the totals', () async {
    await import(h, january);
    final totals = (await h.ledger()).views.of(2026, ViewKind.cash)!;
    final sum = january.statement.lines.fold(0, (a, l) => a + l.amount);
    expect(totals.unclassified.total, sum);
    expect((totals.income.total, totals.expenses.total), (0, 0));
  });

  test('two devices that import the same statement write the same records: no line twice', () async {
    final a = await LedgerHarness.open(deviceId: 'aaaaaaaa-0000-4000-8000-000000000000', now: () => 1000);
    final b = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000', now: () => 2000);
    await seedLedger(a);
    await b.journal.merge(await a.journal.entries());
    await import(a, january);
    await import(b, january);
    final fromA = await a.journal.entries(), fromB = await b.journal.entries();
    await a.journal.merge(fromB);
    await b.journal.merge(fromA);
    const tables = ['statements', 'transactions', 'categories'];
    expect(await a.tables(tables), await b.tables(tables));
    final ledger = await a.ledger();
    expect(ledger.statements, hasLength(1));
    expect(ledger.transactions.values.where((t) => t.isImported), hasLength(27));
    await a.close();
    await b.close();
  });
}
