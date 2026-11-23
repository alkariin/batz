import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/debt.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/proposal.dart';
import 'package:batz/domain/ledger/refund.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/statements.dart';
import '../../support/view_checks.dart';

LedgerError? refusal(void Function() build) {
  try {
    build();
  } on LedgerException catch (e) {
    return e.error;
  }
  return null;
}

/// 120.00 paid in cash on 10.5.2026, split as given.
EntryDraft splitEntry(List<LineDraft> lines, {int cents = 12000, Direction direction = Direction.outflow}) =>
    EntryDraft(
      accountId: 'cash',
      date: d(2026, 5, 10),
      cents: cents,
      direction: direction,
      categoryId: null,
      description: 'Migros',
      lines: lines,
    );

LineDraft line(String id, String category, int cents, {CalendarDate? start, CalendarDate? end}) =>
    LineDraft(id: id, categoryId: category, cents: cents, periodStart: start, periodEnd: end);

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
    await h.apply(
      (l) => l.addCategory('home', year: 2026, name: 'Ménage', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
  });
  tearDown(() => h.close());

  int economic(Ledger ledger, String category, int month) =>
      ledger.views.of(2026, ViewKind.economic)!.categories[category]!.month(month);

  group('a manual entry split between categories', () {
    test('each line has its category, its signed amount and its period; the largest comes first', () async {
      final ledger = await h.apply(
        (l) => l.recordEntry(
          't',
          'unused',
          splitEntry([line('a', 'home', 2000), line('b', 'food', 10000, start: d(2026, 5, 1), end: d(2026, 6, 30))]),
        ),
      );
      final t = ledger.transactions['t']!;
      expect(t.isSplit, isTrue);
      expect(t.amount, -12000);
      expect(t.lines, [
        TransactionLine(
          id: 'b',
          transactionId: 't',
          categoryId: 'food',
          amount: -10000,
          periodStart: d(2026, 5, 1),
          periodEnd: d(2026, 6, 30),
        ),
        TransactionLine(
          id: 'a',
          transactionId: 't',
          categoryId: 'home',
          amount: -2000,
          periodStart: d(2026, 5, 10),
          periodEnd: d(2026, 5, 10),
        ),
      ]);
      expect(t.line!.id, 'b');
      expect(ledger.kindOf(t), TransactionKind.expense);
      expect(ledger.categoriesOf(t).map((c) => c.id), ['food', 'home']);
      // Each line counts in its category, spread over its own period.
      expect((economic(ledger, 'food', 5), economic(ledger, 'food', 6)), (-5000, -5000));
      expect((economic(ledger, 'home', 5), economic(ledger, 'home', 6)), (-2000, 0));
      checkViews(ledger, reason: 'split entry');
    });

    test('refused: a line without amount, lines that do not make the amount, a group, a period that ends before it '
        'starts, a refund attached to an expense', () async {
      final ledger = await h.ledger();
      LedgerError? record(EntryDraft draft) => refusal(() => ledger.recordEntry('t', 'l', draft));
      expect(record(splitEntry([line('a', 'food', 12000), line('b', 'home', 0)])), LedgerError.splitLineAmountInvalid);
      expect(record(splitEntry([line('a', 'food', 10000), line('b', 'home', 1000)])), LedgerError.splitSumMismatch);
      expect(
        record(splitEntry([line('a', 'food', 10000), line('b', 'housing', 2000)])),
        LedgerError.categoryNotAssignable,
      );
      expect(
        record(
          splitEntry([line('a', 'food', 10000), line('b', 'home', 2000, start: d(2026, 5, 2), end: d(2026, 5, 1))]),
        ),
        LedgerError.periodInvalid,
      );
      await h.apply((l) => l.recordEntry('paid', 'paid-line', entry(cents: 5000)));
      final withExpense = await h.ledger();
      expect(
        refusal(
          () => withExpense.recordEntry(
            't',
            'l',
            EntryDraft(
              accountId: 'cash',
              date: d(2026, 5, 10),
              cents: 3000,
              direction: Direction.inflow,
              categoryId: null,
              refundedLineId: 'paid-line',
              lines: [line('a', 'food', 2000), line('b', 'home', 1000)],
            ),
          ),
        ),
        LedgerError.splitRefund,
      );
      expect(ledger.transactions, isEmpty);
    });

    test('modified: lines keep their identifiers, a line left out is deleted, a new one is added', () async {
      await h.apply(
        (l) => l.recordEntry('t', 'unused', splitEntry([line('a', 'food', 10000), line('b', 'home', 2000)])),
      );
      var ledger = await h.apply(
        (l) => l.updateEntry('t', splitEntry([line('a', 'food', 9000), line('c', 'rent', 3000)])),
      );
      expect(
        [for (final x in ledger.transactions['t']!.lines) (x.id, x.categoryId, x.amount)],
        [('a', 'food', -9000), ('c', 'rent', -3000)],
      );
      expect(ledger.linesById.containsKey('b'), isFalse);

      // Brought back to one category, by the line left.
      ledger = await h.apply((l) => l.updateEntry('t', splitEntry([line('c', 'rent', 12000)])));
      final t = ledger.transactions['t']!;
      expect((t.isSplit, t.line!.id, t.line!.categoryId, t.line!.amount), (false, 'c', 'rent', -12000));
      checkViews(ledger, reason: 'unsplit');
    });

    test('modified in one category without lines, a split entry keeps its main line only', () async {
      await h.apply(
        (l) => l.recordEntry('t', 'unused', splitEntry([line('a', 'food', 10000), line('b', 'home', 2000)])),
      );
      final ledger = await h.apply((l) => l.updateEntry('t', entry(cents: 12000, category: 'home')));
      final t = ledger.transactions['t']!;
      expect([for (final x in t.lines) (x.id, x.categoryId, x.amount)], [('a', 'home', -12000)]);
    });

    test('lines may mix natures; the main line gives the type', () async {
      final ledger = await h.apply(
        (l) => l.recordEntry(
          't',
          'unused',
          splitEntry(
            [line('pay', 'salary', 480000), line('fees', 'food', 20000)],
            cents: 500000,
            direction: Direction.inflow,
          ),
        ),
      );
      final t = ledger.transactions['t']!;
      expect(ledger.kindOf(t), TransactionKind.income);
      expect(ledger.views.of(2026, ViewKind.economic)!.categories['salary']!.month(5), 480000);
      expect(economic(ledger, 'food', 5), 20000);
      checkViews(ledger, reason: 'mixed natures');
    });

    test('a split transaction is found by each of its categories', () async {
      await h.apply(
        (l) => l.recordEntry('t', 'unused', splitEntry([line('a', 'food', 10000), line('b', 'home', 2000)])),
      );
      await h.apply((l) => l.recordEntry('other', 'o', entry(cents: 500, description: 'Kiosque')));
      final ledger = await h.ledger();
      expect(ledger.search(const TransactionQuery(categoryName: 'ménage')).map((t) => t.id), ['t']);
      expect(ledger.search(const TransactionQuery(categoryName: 'Nourriture')).map((t) => t.id).toSet(), {
        't',
        'other',
      });
      expect(ledger.search(const TransactionQuery(text: 'menage')).map((t) => t.id), ['t']);
      expect(ledger.search(const TransactionQuery(categoryName: '')), isEmpty);
      expect(ledger.transactionsUsingCategory('home'), 1);
    });
  });

  group('refunds and debts', () {
    Future<Ledger> splitExpense() =>
        h.apply((l) => l.recordEntry('t', 'unused', splitEntry([line('a', 'food', 10000), line('b', 'home', 2000)])));

    test('each line of a split expense can be refunded; the expense counts every refund in its net cost', () async {
      var ledger = await splitExpense();
      expect([for (final e in ledger.refundTargets('migros')) (e.transaction.id, e.line.id)], [('t', 'a'), ('t', 'b')]);
      await h.apply(
        (l) => l.recordEntry(
          'back',
          'back-line',
          EntryDraft(
            accountId: 'cash',
            date: d(2026, 5, 20),
            cents: 500,
            direction: Direction.inflow,
            categoryId: null,
            refundedLineId: 'b',
          ),
        ),
      );
      ledger = await h.ledger();
      expect(ledger.refundsOf(ledger.transactions['t']!).map((t) => t.id), ['back']);
      expect(ledger.netCostOf(ledger.transactions['t']!), -11500);
      expect(economic(ledger, 'home', 5), -1500);
      checkViews(ledger, reason: 'refund of a split line');
    });

    test('attaching a split income to an expense makes it one line', () async {
      await splitExpense();
      await h.apply(
        (l) => l.recordEntry(
          'in',
          'unused',
          splitEntry([line('x', 'salary', 600), line('y', 'food', 400)], cents: 1000, direction: Direction.inflow),
        ),
      );
      final ledger = await h.apply((l) => l.attachRefund('in', 'a'));
      final refund = ledger.transactions['in']!;
      expect([for (final x in refund.lines) (x.id, x.amount, x.refundedLineId)], [('x', 1000, 'a')]);
      checkViews(ledger, reason: 'split attached');
    });

    test('a debt from a split expense is repaid as a refund of its largest expense line; a split repayment stays as '
        'it is', () async {
      await splitExpense();
      await h.apply(
        (l) => l.createDebt(
          'alex',
          const DebtDraft(
            direction: DebtDirection.owedToMe,
            person: 'Alex Modèle',
            amount: 6000,
            basisPoints: 10000,
            sourceTransactionId: 't',
          ),
          today: d(2026, 5, 12),
        ),
      );
      await h.apply((l) => l.recordEntry('back', 'back-line', entry(cents: 6000, direction: Direction.inflow)));
      var ledger = await h.apply((l) => l.repayDebt('alex', 'back', today: d(2026, 5, 20)));
      expect(ledger.transactions['back']!.line!.refundedLineId, 'a');

      await h.apply(
        (l) => l.createDebt(
          'sam',
          const DebtDraft(
            direction: DebtDirection.owedToMe,
            person: 'Sam Modèle',
            amount: 2000,
            basisPoints: 10000,
            sourceTransactionId: 't',
          ),
          today: d(2026, 5, 12),
        ),
      );
      await h.apply(
        (l) => l.recordEntry(
          'mixed',
          'unused',
          splitEntry([line('m1', 'salary', 1500), line('m2', 'food', 500)], cents: 2000, direction: Direction.inflow),
        ),
      );
      ledger = await h.apply((l) => l.repayDebt('sam', 'mixed', today: d(2026, 5, 20)));
      expect(ledger.debts['sam']!.repaid, isTrue);
      expect([for (final x in ledger.transactions['mixed']!.lines) x.refundedLineId], [null, null]);
    });
  });

  group('an imported line split at validation', () {
    late LedgerTransaction purchase;
    late int cents;
    late String main;
    setUp(() async {
      final january = fixtureStatement('2026-01');
      await h.repository.write(
        (await h.ledger()).importStatement('bank', january.statement, fingerprint: january.fingerprint).modification,
      );
      purchase = (await h.ledger())
          .linesOf(statementId('bank', january.fingerprint))
          .firstWhere((t) => t.rawText!.startsWith('ACHAT/SERVICE DU 11.01.2026'));
      cents = purchase.amount.abs();
      main = Ledger.fallbackLineId(purchase.id);
    });

    test('its own line keeps the identifier validation gives it; the lines take the sign of the bank', () async {
      final ledger = await h.apply(
        (l) => l.validateLine(
          purchase.id,
          Classification.split([line(main, 'food', cents - 1), line('extra', 'home', 1)]),
          description: 'Courses',
          note: '',
        ),
      );
      final t = ledger.transactions[purchase.id]!;
      expect((t.isValidated, t.description), (true, 'Courses'));
      expect(
        [for (final x in t.lines) (x.id, x.categoryId, x.amount)],
        [(main, 'food', -(cents - 1)), ('extra', 'home', -1)],
      );
      checkViews(ledger, reason: 'imported split');
    });

    test('refused when the lines do not make the amount of the bank', () async {
      final ledger = await h.ledger();
      expect(
        refusal(() => ledger.classify(purchase.id, Classification.split([line('x', 'food', 1), line('y', 'home', 1)]))),
        LedgerError.splitSumMismatch,
      );
    });

    test('classified again in one category or as a transfer, the other lines are deleted', () async {
      final split = Classification.split([line(main, 'food', cents - 1), line('extra', 'rent', 1)]);
      await h.apply((l) => l.classify(purchase.id, split));
      var ledger = await h.apply(
        (l) => l.classify(
          purchase.id,
          Classification.category('rent', periodStart: purchase.date, periodEnd: purchase.date),
        ),
      );
      expect([for (final x in ledger.transactions[purchase.id]!.lines) (x.id, x.categoryId)], [(main, 'rent')]);

      await h.apply((l) => l.classify(purchase.id, split));
      ledger = await h.apply((l) => l.classify(purchase.id, const Classification.transfer('private')));
      expect(ledger.transactions[purchase.id]!.lines, isEmpty);
      checkViews(ledger, reason: 'transfer');
    });

    test('a line left out of a split, then used again, comes back', () async {
      await h.apply(
        (l) => l.classify(
          purchase.id,
          Classification.category('food', periodStart: purchase.date, periodEnd: purchase.date),
        ),
      );
      await h.apply(
        (l) => l.classify(purchase.id, Classification.split([line('x', 'food', cents - 1), line('y', 'rent', 1)])),
      );
      expect((await h.ledger()).linesById.containsKey(main), isFalse);
      final again = Classification.split([line(main, 'food', cents - 1), line('y', 'rent', 1)]);
      expect(
        (await h.ledger()).classify(purchase.id, again).changes.map((c) => '$c'),
        contains('${FieldChange('transactionLine', main, deletedField, false)}'),
      );
      final ledger = await h.apply((l) => l.classify(purchase.id, again));
      expect(ledger.transactions[purchase.id]!.lines.map((x) => x.id), [main, 'y']);
      expect(ledger.linesById.containsKey('x'), isFalse);
    });
  });
}
