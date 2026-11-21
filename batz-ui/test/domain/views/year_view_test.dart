import 'dart:math';

import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/redistribution.dart';
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

final expenses2026 = defaultGroupId(2026, CategoryNature.expense);

/// The checks every view of every year must pass, whatever the data.
void checkViews(Ledger ledger, {required String reason}) {
  final views = ledger.views;
  final years = views.years(currentYear: 2026);
  for (final year in years) {
    final cash = views.of(year, ViewKind.cash)!, economic = views.of(year, ViewKind.economic)!;
    for (final view in [cash, economic]) {
      final why = '$reason, ${view.kind.name} $year';
      // Every line of the tree: a group is the sum of its children, the
      // income and the expenses the sum of their groups and « À classer ».
      for (final category in view.tree.byId.values) {
        final children = view.tree.childrenOf(category.id);
        if (children.isEmpty) continue;
        expect(
          children.fold(MonthlyAmounts.zero, (sum, c) => sum + view.categories[c.id]! + view.redistributedOf(c.id)),
          view.categories[category.id],
          reason: '$why, ${category.name}',
        );
      }
      for (final nature in CategoryNature.values) {
        final groups = [
          for (final root in view.tree.roots)
            if (root.nature == nature) view.categories[root.id]!,
        ].fold(view.toClassify[nature]!, (a, b) => a + b);
        expect(groups, nature == CategoryNature.income ? view.income : view.expenses, reason: why);
      }
      // Redistribution moves amounts between categories: zero in all.
      expect(
        view.tree.byId.keys.fold(MonthlyAmounts.zero, (sum, id) => sum + view.redistributedOf(id)),
        MonthlyAmounts.zero,
      );
      for (final line in view.redistributions) {
        final source = line.rule.sourceId;
        expect(
          line.moved,
          MonthlyAmounts([
            for (final c in view.categories[source]!.months) redistributedCents(c, line.rule.basisPoints),
          ]),
          reason: why,
        );
      }
      // The sum of the twelve months is the total of each line.
      for (final amounts in [
        ...view.categories.values,
        for (final line in view.redistributions) line.moved,
        ...view.toClassify.values,
        view.unclassified,
        view.income,
        view.expenses,
        view.savings,
      ]) {
        expect(amounts.months.fold(0, (a, b) => a + b), amounts.total, reason: why);
      }
    }
    // Both views differ only by the period offsets.
    expect(
      cash.savings.total,
      economic.savings.total + economic.paidForOtherYears - economic.paidInOtherYears,
      reason: '$reason, identity $year',
    );
    expect((cash.paidForOtherYears, cash.paidInOtherYears), (economic.paidForOtherYears, economic.paidInOtherYears));
    expect(cash.unclassified, economic.unclassified, reason: 'unclassified lines count at their payment date');
    // The cash-flow total is the sum of the payments of the year, transfers
    // left out.
    final paid = [
      for (final t in ledger.transactions.values)
        if (t.date.year == year && ledger.kindOf(t) != TransactionKind.transfer) t.amount,
    ].fold(0, (a, b) => a + b);
    expect(cash.income.total + cash.expenses.total + cash.unclassified.total, paid, reason: '$reason, cash $year');
  }
}

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
  });
  tearDown(() => h.close());

  group('the example of the specification', () {
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
      expect(economic2027.isPreview, isTrue, reason: '2027 has no tree yet: the copy to come (H6)');
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
  });

  group('between years (principle 3)', () {
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

    test('a category of the same name that became a group is no counterpart (H5)', () async {
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

    test(
      'a year before the first tree is not shown: its shares stay in the offsets of the payment year (H6)',
      () async {
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
      },
    );

    test(
      'a year to come is shown with the tree of its copy (H6), as long as amounts or the current year reach it',
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

  test('on random data: twelve months make each total, the cash-flow total is the sum of the payments, the identity '
      'of the offsets holds, and over all years both views total the same', () {
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
