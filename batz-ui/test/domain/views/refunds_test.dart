import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/category.dart';
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

/// A refund entered by hand, attached to the expense line [expenseLine].
EntryDraft refund({required String expenseLine, required int cents, required CalendarDate date}) => EntryDraft(
  accountId: 'cash',
  date: date,
  cents: cents,
  direction: Direction.inflow,
  categoryId: null,
  refundedLineId: expenseLine,
);

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
    await h.apply(
      (l) =>
          l.addCategory('doctor', year: 2026, name: 'Médecin', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
  });
  tearDown(() => h.close());

  /// The expense of the criterion: 300 paid on 15.1.2026 for January to
  /// March.
  Future<void> visit() => h.apply(
    (l) => l.recordEntry(
      'visit',
      'visit-line',
      entry(
        category: 'doctor',
        cents: 30000,
        date: d(2026, 1, 15),
        periodStart: d(2026, 1, 1),
        periodEnd: d(2026, 3, 31),
      ),
    ),
  );

  test(
    'a 300 expense for January to March and a refund of 120 received in May, attached: a net cost of 60 a month '
    'from January to March in the economic view, nothing in May; in cash flow, 300 in January and 120 in May',
    () async {
      await visit();
      await h.apply(
        (l) =>
            l.recordEntry('back', 'back-line', refund(expenseLine: 'visit-line', cents: 12000, date: d(2026, 5, 20))),
      );
      final ledger = await h.ledger();
      final economic = ledger.views.of(2026, ViewKind.economic)!, cash = ledger.views.of(2026, ViewKind.cash)!;
      expect(economic.categories['doctor']!.months, [-6000, -6000, -6000, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      expect(cash.categories['doctor']!.months, [-30000, 0, 0, 0, 12000, 0, 0, 0, 0, 0, 0, 0]);
      expect(economic.unclassified.total, 0);
      final expense = ledger.transactions['visit']!, back = ledger.transactions['back']!;
      expect(ledger.refundsOf(expense), [back]);
      expect(ledger.netCostOf(expense), -18000);
      expect(ledger.expenseOf(back)!.transaction.id, 'visit');
      expect((ledger.kindOf(back), ledger.categoryOf(back)?.id), (TransactionKind.refund, 'doctor'));
      expect(back.line!.periodStart, d(2026, 5, 20), reason: 'its own period is its date');
      expect(
        [
          for (final c in ledger.views.composition(2026, ViewKind.economic, const CategoryRow('doctor'), month: 2))
            (c.transaction.id, c.cents),
        ],
        [('visit', -10000), ('back', 4000)],
      );
      checkViews(ledger, reason: 'criterion');
    },
  );

  test('a refund received the year after: in cash flow in the category of the same name of its year, in the economic '
      'view with the expense; the offsets say so', () async {
    await h.apply(
      (l) => l.recordEntry('visit', 'visit-line', entry(category: 'doctor', cents: 50000, date: d(2026, 11, 10))),
    );
    await h.apply(
      (l) => l.recordEntry('back', 'back-line', refund(expenseLine: 'visit-line', cents: 20000, date: d(2027, 2, 5))),
    );
    final ledger = await h.ledger();
    final doctor2027 = copiedCategoryId('doctor', 2027);
    expect(
      ledger.transactions['back']!.line!.categoryId,
      doctor2027,
      reason: 'its own category: the same name in 2027',
    );
    final cash2027 = ledger.views.of(2027, ViewKind.cash)!, economic2027 = ledger.views.of(2027, ViewKind.economic)!;
    expect(cash2027.categories[doctor2027]!.month(2), 20000);
    expect(economic2027.expenses.total, 0);
    final economic2026 = ledger.views.of(2026, ViewKind.economic)!;
    expect(economic2026.categories['doctor']!.month(11), -30000);
    expect((economic2027.paidForOtherYears, economic2026.paidInOtherYears), (20000, 20000));
    checkViews(ledger, reason: 'next year');
  });

  test('an attached refund follows a change of period or of category of its expense', () async {
    await visit();
    await h.apply(
      (l) => l.recordEntry('back', 'back-line', refund(expenseLine: 'visit-line', cents: 12000, date: d(2026, 5, 20))),
    );
    await h.apply(
      (l) => l.updateEntry(
        'visit',
        entry(
          category: 'doctor',
          cents: 30000,
          date: d(2026, 1, 15),
          periodStart: d(2026, 4, 1),
          periodEnd: d(2026, 6, 30),
        ),
      ),
    );
    var view = (await h.ledger()).views.of(2026, ViewKind.economic)!;
    expect(view.categories['doctor']!.months.sublist(0, 6), [0, 0, 0, -6000, -6000, -6000]);
    await h.apply(
      (l) => l.updateEntry(
        'visit',
        entry(
          category: 'food',
          cents: 30000,
          date: d(2026, 1, 15),
          periodStart: d(2026, 4, 1),
          periodEnd: d(2026, 6, 30),
        ),
      ),
    );
    final ledger = await h.ledger();
    view = ledger.views.of(2026, ViewKind.economic)!;
    expect(view.totalOf('doctor'), 0);
    expect(view.categories['food']!.months.sublist(3, 6), [-6000, -6000, -6000]);
    expect(ledger.categoryOf(ledger.transactions['back']!)!.id, 'food');
    expect(ledger.views.of(2026, ViewKind.cash)!.categories['food']!.month(5), 12000);
  });

  test('several refunds of one expense', () async {
    await visit();
    await h.apply(
      (l) => l.recordEntry('back1', 'b1', refund(expenseLine: 'visit-line', cents: 12000, date: d(2026, 5, 20))),
    );
    await h.apply(
      (l) => l.recordEntry('back2', 'b2', refund(expenseLine: 'visit-line', cents: 3000, date: d(2026, 4, 2))),
    );
    final ledger = await h.ledger();
    expect(ledger.refundsOf(ledger.transactions['visit']!).map((t) => t.id), ['back2', 'back1']);
    expect(ledger.netCostOf(ledger.transactions['visit']!), -15000);
    expect(ledger.views.of(2026, ViewKind.economic)!.categories['doctor']!.months.sublist(0, 3), [-5000, -5000, -5000]);
  });

  test(
    'detached, or its expense deleted, a refund gets back its own category and its date; a broken link is listed',
    () async {
      await visit();
      await h.apply(
        (l) =>
            l.recordEntry('back', 'back-line', refund(expenseLine: 'visit-line', cents: 12000, date: d(2026, 5, 20))),
      );
      // The expense moves to « Nourriture »: the refund follows it, and keeps
      // « Médecin » as its own category.
      await h.apply((l) => l.updateEntry('visit', entry(category: 'food', cents: 30000, date: d(2026, 1, 15))));
      var ledger = await h.ledger();
      expect(ledger.views.of(2026, ViewKind.economic)!.categories['food']!.month(1), -18000);
      expect(ledger.brokenRefunds, isEmpty);

      await h.apply((l) => l.deleteTransaction('visit'));
      ledger = await h.ledger();
      final economic = ledger.views.of(2026, ViewKind.economic)!;
      expect(economic.categories['doctor']!.month(5), 12000, reason: 'its own category, at its date');
      expect(economic.totalOf('food'), 0);
      expect(ledger.brokenRefunds.map((t) => t.id), ['back']);
      expect(ledger.categoryOf(ledger.transactions['back']!)!.id, 'doctor');

      await h.apply((l) => l.detachRefund('back'));
      ledger = await h.ledger();
      expect(ledger.brokenRefunds, isEmpty);
      expect(ledger.transactions['back']!.line!.refundedLineId, isNull);
      expect(ledger.views.of(2026, ViewKind.economic)!.categories['doctor']!.month(5), 12000);
      expect(refusal(() => ledger.detachRefund('back')), LedgerError.unknownTransaction);
    },
  );

  test('imported lines: attaching a line to validate validates it; deleting the statement of the expense breaks the '
      'link without error; classifying the refund in a category detaches it', () async {
    final january = fixtureStatement('2026-01');
    await h.repository.write(
      (await h.ledger()).importStatement('bank', january.statement, fingerprint: january.fingerprint).modification,
    );
    var ledger = await h.ledger();
    final lines = ledger.linesOf(statementId('bank', january.fingerprint));
    final purchase = lines.firstWhere((t) => t.rawText!.startsWith('ACHAT/SERVICE DU 11.01.2026'));
    final credit = lines.firstWhere((t) => t.rawText!.startsWith('CRÉDIT POSTFINANCE CARD'));
    expect((purchase.amount < 0, credit.amount > 0), (true, true));
    expect(
      refusal(() => ledger.attachRefund(credit.id, '${purchase.id}-line')),
      LedgerError.refundTargetNotExpense,
      reason: 'the purchase is still to validate',
    );
    await h.apply(
      (l) => l.classify(
        purchase.id,
        Classification.category('food', periodStart: purchase.date, periodEnd: purchase.date),
      ),
    );
    await h.apply((l) => l.attachRefund(credit.id, '${purchase.id}-line'));
    ledger = await h.ledger();
    final attached = ledger.transactions[credit.id]!;
    expect(attached.isValidated, isTrue);
    expect((attached.line!.categoryId, attached.line!.refundedLineId), ('food', '${purchase.id}-line'));
    expect(ledger.netCostOf(ledger.transactions[purchase.id]!), purchase.amount + credit.amount);

    // Classified in a category, the refund is no longer attached.
    await h.apply(
      (l) => l.classify(credit.id, Classification.category('doctor', periodStart: credit.date, periodEnd: credit.date)),
    );
    ledger = await h.ledger();
    expect(ledger.transactions[credit.id]!.line!.refundedLineId, isNull);
    expect(ledger.refundsOf(ledger.transactions[purchase.id]!), isEmpty);

    // A refund by hand attached to the imported purchase, then the statement
    // deleted: the link breaks, nothing fails.
    await h.apply(
      (l) =>
          l.recordEntry('cash-back', 'cb', refund(expenseLine: '${purchase.id}-line', cents: 500, date: d(2026, 2, 1))),
    );
    await h.apply((l) => l.deleteLastStatement(statementId('bank', january.fingerprint)));
    ledger = await h.ledger();
    expect(ledger.brokenRefunds.map((t) => t.id), ['cash-back']);
    expect(ledger.views.of(2026, ViewKind.economic)!.categories['food']!.month(2), 500);
    checkViews(ledger, reason: 'statement deleted');
  });

  test('refusals: money that left, a transfer, a target that is not a validated expense', () async {
    await visit();
    await h.apply(
      (l) => l.recordEntry('salary', 'sl', entry(category: 'salary', cents: 500000, direction: Direction.inflow)),
    );
    await h.apply((l) => l.recordEntry('gift', 'gl', entry(cents: 1000, direction: Direction.inflow)));
    await h.apply((l) => l.recordEntry('spent', 'spl', entry(cents: 1000)));
    await h.apply((l) => l.recordTransfer('move', transfer(from: 'cash', to: 'private', cents: 1000)));
    await h.apply((l) => l.recordTransfer('back-move', transfer(from: 'private', to: 'cash', cents: 1000)));
    final ledger = await h.ledger();
    expect(refusal(() => ledger.attachRefund('spent', 'visit-line')), LedgerError.refundNotInflow);
    expect(refusal(() => ledger.attachRefund('move', 'visit-line')), LedgerError.refundIsTransfer);
    expect(refusal(() => ledger.attachRefund('gift', 'sl')), LedgerError.refundTargetNotExpense, reason: 'an income');
    expect(refusal(() => ledger.attachRefund('salary', 'gl')), LedgerError.refundTargetNotExpense, reason: 'a refund');
    expect(refusal(() => ledger.attachRefund('gift', 'none')), LedgerError.refundTargetNotExpense);
    expect(refusal(() => ledger.attachRefund('none', 'visit-line')), LedgerError.unknownTransaction);
    expect(
      refusal(
        () => ledger.recordEntry(
          'x',
          'xl',
          EntryDraft(
            accountId: 'cash',
            date: d(2026, 6, 1),
            cents: 100,
            direction: Direction.outflow,
            categoryId: null,
            refundedLineId: 'visit-line',
          ),
        ),
      ),
      LedgerError.refundNotInflow,
    );
    expect(refusal(() => ledger.attachRefund('gift', 'visit-line')), isNull);
    expect(ledger.refundTargets('').map((t) => t.id).toSet(), {'visit', 'spent'});
    expect(ledger.refundTargets('300.00').map((t) => t.id), ['visit']);
  });

  test('a chain made by two devices has no effect: a link leads to an expense or does not hold', () async {
    await h.apply((l) => l.recordEntry('e', 'el', entry(category: 'doctor', cents: 10000, date: d(2026, 3, 1))));
    await h.apply((l) => l.recordEntry('f', 'fl', entry(category: 'doctor', cents: 4000, date: d(2026, 3, 2))));
    await h.apply(
      (l) => l.recordEntry('r', 'rl', entry(cents: 2000, direction: Direction.inflow, date: d(2026, 3, 3))),
    );
    final other = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000');
    addTearDown(other.close);
    await other.journal.merge(await h.journal.entries());
    // Here, « r » refunds « e »; there, « e » becomes money that came in and
    // refunds « f ».
    await h.apply((l) => l.attachRefund('r', 'el'));
    await other.apply(
      (l) => l.updateEntry(
        'e',
        EntryDraft(
          accountId: 'cash',
          date: d(2026, 3, 1),
          cents: 10000,
          direction: Direction.inflow,
          categoryId: null,
          refundedLineId: 'fl',
        ),
      ),
    );
    await other.journal.merge(await h.journal.entries());
    await h.journal.merge(await other.journal.entries());
    final ledger = await h.ledger();
    expect(ledger.brokenRefunds.map((t) => t.id), ['r'], reason: '« e » is no longer an expense');
    expect(ledger.refundsOf(ledger.transactions['f']!).map((t) => t.id), ['e']);
    expect(ledger.netCostOf(ledger.transactions['f']!), 6000);
    final view = ledger.views.of(2026, ViewKind.economic)!;
    // « e » follows « f »; « r » is back in its own category, the one of
    // the same name as the expense it was attached to.
    expect(view.categories['doctor']!.month(3), -4000 + 10000 + 2000);
    expect(view.totalOf('food'), 0);
    checkViews(ledger, reason: 'chain');
  });
}
