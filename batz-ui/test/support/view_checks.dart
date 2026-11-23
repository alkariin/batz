import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/views/share_operations.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

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
      // A percentage applies, month by month, to what the source shows once
      // its fixed amounts are out; a fixed amount moves money of the sign
      // of its source's nature, at most what the source's payments hold.
      for (final line in view.redistributions) {
        final source = line.rule.sourceId;
        final fixedOut = [
          for (final other in view.redistributions)
            if (other.rule.isFixed && other.rule.sourceId == source) other.moved,
        ].fold(MonthlyAmounts.zero, (a, b) => a + b);
        if (line.rule.isFixed) {
          final income = view.tree.natureOf(source) == CategoryNature.income;
          expect(line.moved.months.every((c) => income ? c >= 0 : c <= 0), isTrue, reason: why);
          continue;
        }
        expect(
          line.moved,
          MonthlyAmounts([
            for (final (i, c) in view.categories[source]!.months.indexed)
              redistributedCents(c - fixedOut.months[i], line.rule.basisPoints!),
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
    // The questions waiting hold exactly what « À classer » shows.
    for (final nature in CategoryNature.values) {
      final groups = views.pendingShares.where((g) => g.year == year && g.nature == nature);
      expect(
        groups.expand((g) => g.shares).fold(0, (sum, s) => sum + s.economic),
        economic.toClassify[nature]!.total,
        reason: '$reason, pending economic $year',
      );
      expect(
        groups.expand((g) => g.shares).fold(0, (sum, s) => sum + s.cash),
        cash.toClassify[nature]!.total,
        reason: '$reason, pending cash $year',
      );
    }
    // Both views differ only by the period offsets.
    expect(
      cash.savings.total,
      economic.savings.total + economic.paidForOtherYears - economic.paidInOtherYears,
      reason: '$reason, identity $year',
    );
    expect((cash.paidForOtherYears, cash.paidInOtherYears), (economic.paidForOtherYears, economic.paidInOtherYears));
    expect(cash.unclassified, economic.unclassified, reason: 'unclassified lines count at their payment date');
    // The cash-flow result plus « Non classé » is the sum of the payments
    // of the year, transfers left out: each transaction counts for exactly
    // its amount, whatever its lines add up to after a merge.
    final paid = [
      for (final t in ledger.transactions.values)
        if (t.date.year == year && ledger.kindOf(t) != TransactionKind.transfer) t.amount,
    ].fold(0, (a, b) => a + b);
    expect(cash.income.total + cash.expenses.total + cash.unclassified.total, paid, reason: '$reason, cash $year');
  }
  expect(ledger.pendingShareCount, views.pendingShares.fold(0, (sum, g) => sum + g.shares.length));
}
