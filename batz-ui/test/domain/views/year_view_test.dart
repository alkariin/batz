import 'dart:math';

import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/refund.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/period_model.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/random_ledger.dart';
import '../../support/statements.dart';
import '../../support/view_checks.dart';

final expenses2026 = defaultGroupId(2026, CategoryNature.expense);

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
  });
  tearDown(() => h.close());

  group('the reference example', () {
    test('2\'100 paid in 2026 for 1.9.2026 – 31.8.2027: 2\'100 in cash 2026; 700 in economic 2026 and 1\'400 in 2027; '
        '1\'400 of offset in each year', () async {
      await h.apply(
        (l) => l.recordEntry(
          'insurance',
          'l1',
          entry(
            category: 'rent',
            cents: 210000,
            date: d(2026, 9, 1),
            periodStart: d(2026, 9, 1),
            periodEnd: d(2027, 8, 31),
          ),
        ),
      );
      final views = (await h.ledger()).views;
      final rent2027 = copiedCategoryId('rent', 2027);

      final cash2026 = views.of(2026, ViewKind.cash)!, economic2026 = views.of(2026, ViewKind.economic)!;
      expect(cash2026.totalOf('rent'), -210000);
      expect(cash2026.categories['rent']!.month(9), -210000);
      expect(economic2026.totalOf('rent'), -70000);
      expect(economic2026.categories['rent']!.months, [0, 0, 0, 0, 0, 0, 0, 0, -17500, -17500, -17500, -17500]);

      final cash2027 = views.of(2027, ViewKind.cash)!, economic2027 = views.of(2027, ViewKind.economic)!;
      expect(economic2027.isPreview, isTrue, reason: '2027 has no tree yet: the copy to come');
      expect(economic2027.tree.byId[rent2027]!.name, 'Loyer');
      expect(economic2027.totalOf(rent2027), -140000);
      expect(cash2027.expenses.total, 0);

      expect((economic2026.paidForOtherYears, economic2026.paidInOtherYears), (-140000, 0));
      expect((economic2027.paidForOtherYears, economic2027.paidInOtherYears), (0, -140000));
      for (final (cash, economic) in [(cash2026, economic2026), (cash2027, economic2027)]) {
        expect(cash.savings.total, economic.savings.total + economic.paidForOtherYears - economic.paidInOtherYears);
      }
    });
  });

  test('a group adds up its children; income, expenses and savings; a transfer counts nowhere', () async {
    await h.apply((l) => l.addCategory('charges', year: 2026, name: 'Charges', parentId: 'housing'));
    await h.apply((l) => l.recordEntry('a', 'la', entry(category: 'rent', cents: 150000, date: d(2026, 1, 5))));
    await h.apply((l) => l.recordEntry('b', 'lb', entry(category: 'charges', cents: 20000, date: d(2026, 2, 5))));
    await h.apply(
      (l) => l.recordEntry(
        'c',
        'lc',
        entry(category: 'salary', cents: 600000, direction: Direction.inflow, date: d(2026, 1, 25)),
      ),
    );
    await h.apply((l) => l.recordEntry('refund', 'ld', entry(cents: 3000, direction: Direction.inflow)));
    await h.apply((l) => l.recordTransfer('t', transfer()));
    final view = (await h.ledger()).views.of(2026, ViewKind.economic)!;
    expect(view.categories['housing']!.months.sublist(0, 2), [-150000, -20000]);
    expect(view.totalOf('housing'), -170000);
    expect(view.totalOf(expenses2026), -167000, reason: 'a refund diminishes its category');
    expect((view.income.total, view.expenses.total, view.savings.total), (600000, -167000, 433000));
    expect(view.savings.month(1), 450000);
  });

  group('unclassified', () {
    test('lines to validate without a proposal count at their payment date in both views, outside income and '
        'expenses; proposed lines count as proposed, period included', () async {
      final january = fixtureStatement('2026-01');
      await h.repository.write(
        (await h.ledger()).importStatement('bank', january.statement, fingerprint: january.fingerprint).modification,
      );
      await h.apply(
        (l) => l.createRule(
          'groceries',
          const RuleDraft(
            year: 2026,
            keywords: ['épicerie du coin'],
            targetCategoryId: 'food',
            periodModel: PeriodModel.nextMonth,
          ),
        ),
      );
      await h.apply(
        (l) =>
            l.createRule('savings', const RuleDraft(year: 2026, keywords: ['compte épargne'], targetAccountId: 'cash')),
      );
      final ledger = await h.ledger();
      final lines = ledger.linesOf(statementId('bank', january.fingerprint));
      final groceries = lines.where((t) => t.rawText!.contains('Épicerie du Coin')).fold(0, (a, t) => a + t.amount);
      final saving = lines.singleWhere((t) => t.rawText!.contains('Compte épargne')).amount;
      final all = lines.fold(0, (a, t) => a + t.amount);
      for (final kind in ViewKind.values) {
        final view = ledger.views.of(2026, kind)!;
        expect(view.unclassified.month(1), all - groceries - saving, reason: kind.name);
        expect(view.unclassified.total, all - groceries - saving);
        expect(view.expenses.total, groceries);
        expect(view.linesToValidate, lines.length - 1, reason: 'the proposed transfer counts nowhere');
      }
      expect(ledger.views.of(2026, ViewKind.cash)!.categories['food']!.month(1), groceries);
      expect(ledger.views.of(2026, ViewKind.economic)!.categories['food']!.month(2), groceries, reason: 'next month');
    });

    test('a validated line whose category is no longer in the tree of its payment year is unclassified', () async {
      await h.apply((l) => l.recordEntry('a', 'la', entry(category: 'food', cents: 5000)));
      // Another device deleted « Nourriture »: the line keeps its category.
      await h.repository.write(Modification.delete(CategoryFields.entity, 'food'));
      final view = (await h.ledger()).views.of(2026, ViewKind.economic)!;
      expect(view.unclassified.total, -5000);
      expect(view.expenses.total, 0);
    });

    test('a merge: an amount corrected on one device, the same entry attached on another, keeps both '
        'amounts equal, since attaching writes no unchanged amount', () async {
      var wallA = 1000, wallB = 1000;
      final a = await LedgerHarness.open(deviceId: 'aaaaaaaa-0000-4000-8000-000000000000', now: () => wallA);
      final b = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000', now: () => wallB);
      addTearDown(a.close);
      addTearDown(b.close);
      await seedLedger(a);
      await a.apply(
        (l) => l.recordEntry('visit', 'visit-line', entry(category: 'food', cents: 30000, date: d(2026, 1, 15))),
      );
      await a.apply(
        (l) => l.recordEntry(
          'back',
          'back-line',
          entry(category: 'food', cents: 12000, direction: Direction.inflow, date: d(2026, 5, 20)),
        ),
      );
      await b.journal.merge(await a.journal.entries());

      // Offline: A corrects the amount of the refund; B, later, attaches it.
      wallA = 5000;
      await a.apply(
        (l) => l.updateEntry(
          'back',
          entry(category: 'food', cents: 15000, direction: Direction.inflow, date: d(2026, 5, 20)),
        ),
      );
      wallB = 7000;
      await b.apply((l) => l.attachRefund('back', 'visit-line'));
      final written = (await b.journal.entries()).where((e) => e.hlc.millis == 7000).map((e) => e.field).toSet();
      expect(written, {LineFields.refundedLineId}, reason: 'the amount B knows is the one it would write');
      final fromA = await a.journal.entries(), fromB = await b.journal.entries();
      await a.journal.merge(fromB);
      await b.journal.merge(fromA);
      for (final device in [a, b]) {
        final ledger = await device.ledger();
        final t = ledger.transactions['back']!;
        expect((t.amount, t.line!.amount, t.line!.refundedLineId), (15000, 15000, 'visit-line'));
        expect(ledger.views.of(2026, ViewKind.cash)!.unclassified.total, 0);
      }
    });

    test('a line whose amount differs from the amount of its transaction, as a device of another version or one already holding '
        'such a gap can write it: the transaction counts for exactly its amount, the difference is unclassified at '
        'its payment date, until it is saved again', () async {
      await h.apply(
        (l) => l.recordEntry('visit', 'visit-line', entry(category: 'food', cents: 30000, date: d(2026, 1, 15))),
      );
      await h.apply(
        (l) => l.recordEntry(
          'back',
          'back-line',
          EntryDraft(
            accountId: 'cash',
            date: d(2026, 5, 20),
            cents: 15000,
            direction: Direction.inflow,
            categoryId: null,
            refundedLineId: 'visit-line',
          ),
        ),
      );
      // Another device wrote the line with the amount it knew.
      await h.repository.write(Modification.set(LineFields.entity, 'back-line', {LineFields.amount: 12000}));

      final merged = await h.ledger();
      final t = merged.transactions['back']!;
      expect((t.amount, t.line!.amount, t.line!.refundedLineId), (15000, 12000, 'visit-line'));
      for (final kind in ViewKind.values) {
        final view = merged.views.of(2026, kind)!;
        expect(view.unclassified.months, [0, 0, 0, 0, 3000, 0, 0, 0, 0, 0, 0, 0], reason: kind.name);
        expect(view.expenses.total, -30000 + 12000, reason: kind.name);
        expect(view.savings.total + view.unclassified.total, -30000 + 15000, reason: 'the payments of the year');
        expect(
          [for (final c in merged.views.composition(2026, kind, const UnclassifiedRow())) (c.transaction.id, c.cents)],
          [('back', 3000)],
        );
      }

      // Saved again as it stands: both amounts are written, nothing is left
      // unclassified.
      final again = await h.apply(
        (l) => l.updateEntry(
          'back',
          EntryDraft(
            accountId: t.accountId,
            date: t.date,
            cents: t.amount,
            direction: Direction.inflow,
            categoryId: t.line!.categoryId,
            refundedLineId: t.line!.refundedLineId,
          ),
        ),
      );
      expect(again.transactions['back']!.line!.amount, 15000);
      expect(again.views.of(2026, ViewKind.cash)!.unclassified.total, 0);
      expect(again.views.of(2026, ViewKind.economic)!.expenses.total, -30000 + 15000);
    });
  });

  group('between years', () {
    test('a share goes to the category of the same name in its year, found again after a rename', () async {
      await h.apply((l) => l.createTree(2027));
      await h.apply(
        (l) => l.recordEntry(
          'a',
          'la',
          entry(
            category: 'food',
            cents: 120000,
            date: d(2026, 7, 1),
            periodStart: d(2026, 7, 1),
            periodEnd: d(2027, 6, 30),
          ),
        ),
      );
      final food2027 = copiedCategoryId('food', 2027);
      var view = (await h.ledger()).views.of(2027, ViewKind.economic)!;
      expect(view.totalOf(food2027), -60000);
      expect(view.toClassify[CategoryNature.expense]!.total, 0);

      // Renamed in 2027: no counterpart any more, « À classer », still an
      // expense of 2027.
      await h.apply((l) => l.renameCategory(food2027, 'Alimentation'));
      view = (await h.ledger()).views.of(2027, ViewKind.economic)!;
      expect(view.totalOf(food2027), 0);
      expect(view.toClassify[CategoryNature.expense]!.months.sublist(0, 6), List.filled(6, -10000));
      expect(view.expenses.total, -60000);

      // Renamed back: found again, on the next load.
      await h.apply((l) => l.renameCategory(food2027, 'nourriture'));
      expect((await h.ledger()).views.of(2027, ViewKind.economic)!.totalOf(food2027), -60000);
    });

    test('a category of the same name that became a group is no counterpart', () async {
      await h.apply((l) => l.createTree(2027));
      await h.apply(
        (l) => l.addCategory('fresh', year: 2027, name: 'Produits frais', parentId: copiedCategoryId('food', 2027)),
      );
      await h.apply(
        (l) => l.recordEntry(
          'a',
          'la',
          entry(
            category: 'food',
            cents: 24000,
            date: d(2026, 12, 1),
            periodStart: d(2026, 12, 1),
            periodEnd: d(2027, 1, 31),
          ),
        ),
      );
      final view = (await h.ledger()).views.of(2027, ViewKind.economic)!;
      expect(view.toClassify[CategoryNature.expense]!.month(1), -12000);
      expect(view.totalOf(copiedCategoryId('food', 2027)), 0);
    });

    test('a year before the first tree is not shown: its shares stay in the offsets of the payment year', () async {
      await h.apply(
        (l) => l.recordEntry(
          'taxes',
          'lt',
          entry(
            category: 'food',
            cents: 365000,
            date: d(2026, 3, 31),
            periodStart: d(2025, 1, 1),
            periodEnd: d(2025, 12, 31),
          ),
        ),
      );
      final ledger = await h.ledger();
      expect(ledger.views.of(2025, ViewKind.economic), isNull);
      expect(ledger.views.of(2025, ViewKind.cash), isNull);
      final economic = ledger.views.of(2026, ViewKind.economic)!;
      expect(economic.expenses.total, 0);
      expect(economic.paidForOtherYears, -365000);
      expect(ledger.views.of(2026, ViewKind.cash)!.expenses.total, -365000);
      expect(ledger.views.years(currentYear: 2026), [2026]);
    });

    test(
      'a year to come is shown with the tree of its copy, as long as amounts or the current year reach it',
      () async {
        await h.apply(
          (l) => l.recordEntry(
            'a',
            'la',
            entry(
              category: 'rent',
              cents: 360000,
              date: d(2026, 1, 1),
              periodStart: d(2026, 1, 1),
              periodEnd: d(2028, 12, 31),
            ),
          ),
        );
        final ledger = await h.ledger();
        expect(ledger.views.years(currentYear: 2026), [2026, 2027, 2028]);
        expect(ledger.views.years(currentYear: 2030), [2026, 2027, 2028, 2029, 2030]);
        final view = ledger.views.of(2028, ViewKind.economic)!;
        expect(view.isPreview, isTrue);
        expect(view.tree.ordered.map((c) => c.name), ledger.trees[2026]!.ordered.map((c) => c.name));
        expect(view.totalOf(copiedCategoryId('rent', 2028)), -120000);
        expect(ledger.views.isPreview(2026), isFalse);
      },
    );
  });

  test(
    'the composition of an amount: the transactions of a category, of a month, with the part each one counts',
    () async {
      await h.apply((l) => l.addCategory('charges', year: 2026, name: 'Charges', parentId: 'housing'));
      await h.apply((l) => l.recordEntry('rent', 'l1', entry(category: 'rent', cents: 150000, date: d(2026, 1, 5))));
      await h.apply(
        (l) => l.recordEntry(
          'heating',
          'l2',
          entry(
            category: 'charges',
            cents: 120000,
            date: d(2026, 1, 20),
            periodStart: d(2026, 1, 1),
            periodEnd: d(2026, 12, 31),
          ),
        ),
      );
      final views = (await h.ledger()).views;
      List<(String, int)> parts(ViewKind kind, ViewRow row, {int? month}) => [
        for (final c in views.composition(2026, kind, row, month: month)) (c.transaction.id, c.cents),
      ];
      expect(parts(ViewKind.cash, const CategoryRow('housing')), [('rent', -150000), ('heating', -120000)]);
      expect(parts(ViewKind.economic, const CategoryRow('housing'), month: 3), [('heating', -10000)]);
      expect(parts(ViewKind.economic, const CategoryRow('charges')), [('heating', -120000)]);
      expect(parts(ViewKind.economic, const CategoryRow('food')), isEmpty);
      expect(parts(ViewKind.economic, const UnclassifiedRow()), isEmpty);
    },
  );

  test('on random data: twelve months make each total, the cash-flow result plus « Non classé » is the sum of the '
      'payments outside transfers, merge gaps included, the identity of the offsets holds, and over all years both '
      'views total the same', () {
    for (var seed = 1; seed <= 20; seed++) {
      final ledger = randomLedger(Random(seed));
      checkViews(ledger, reason: 'seed $seed');
      final views = ledger.views;
      expect(views.years(currentYear: 2026), randomYears, reason: 'seed $seed');
      int all(ViewKind kind) => [
        for (final year in randomYears) views.of(year, kind)!.savings.total + views.of(year, kind)!.unclassified.total,
      ].fold(0, (a, b) => a + b);
      expect(all(ViewKind.economic), all(ViewKind.cash), reason: 'seed $seed');
      expect(views.of(2026, ViewKind.economic)!.paidForOtherYears, isNot(0), reason: 'seed $seed');
      expect(ledger.refundsByExpenseLine, isNotEmpty, reason: 'seed $seed');
      expect(ledger.shareClassifications, isNotEmpty, reason: 'seed $seed');
      expect(
        ledger.shareClassifications.keys.where((key) => views.answerOf(key.$1, key.$2) != null),
        isNotEmpty,
        reason: 'seed $seed: answers that hold',
      );
      expect(views.pendingShares, isNotEmpty, reason: 'seed $seed');
      expect(ledger.brokenRefunds, isNotEmpty, reason: 'seed $seed');
      expect(
        ledger.transactions.values.where((t) => t.lines.isNotEmpty && t.lines.single.amount != t.amount),
        isNotEmpty,
        reason: 'seed $seed: merge gaps, which checkViews counts in the payments of their year',
      );
      for (final year in randomYears) {
        final view = views.of(year, ViewKind.economic)!;
        expect(view.redistributions, hasLength(year == 2026 ? 2 : 3), reason: 'seed $seed, $year');
        expect(view.inapplicable.length, year == 2026 ? 1 : 0, reason: 'seed $seed, $year');
      }
      expect(views.of(2027, ViewKind.economic)!.paidInOtherYears, isNot(0), reason: 'seed $seed');
      expect(
        views.of(2027, ViewKind.economic)!.toClassify[CategoryNature.expense]!.total,
        isNot(0),
        reason: 'seed $seed: « Loisirs » and « Assurances » have no counterpart in 2027',
      );
    }
  });
}
