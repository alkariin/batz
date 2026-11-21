import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/views/wealth.dart';
import 'package:batz/domain/views/year_view.dart';

/// Every amount of the annual views (both views, every year shown) and of
/// the wealth seen on [today] (each table, the curve, the accounts): what no
/// entry of a module may change (principle 3 of phase 6).
Map<String, Object> accountsAndViews(Ledger ledger, CalendarDate today) {
  final views = ledger.views;
  final wealth = ledger.wealth(today);
  return {
    for (final year in views.years(currentYear: today.year))
      for (final kind in ViewKind.values)
        'view $year ${kind.name}': () {
          final view = views.of(year, kind)!;
          return [
            view.categories,
            view.toClassify,
            view.unclassified,
            view.income,
            view.expenses,
            view.paidForOtherYears,
            view.paidInOtherYears,
            [for (final line in view.redistributions) (line.rule.id, line.moved)],
          ];
        }(),
    for (final year in wealth.years)
      'wealth $year': () {
        final t = wealth.explain(year);
        return [
          t.economicResult,
          t.cashResult,
          t.valueVariationsTotal,
          t.addedAccountsTotal,
          t.debtsChange,
          t.unclassified,
          t.outsideWealthTotal,
          t.wealthAtStart,
          t.wealthAtEnd,
        ];
      }(),
    'curve': [for (final m in wealth.monthly) m.amount],
    'accounts': [for (final a in wealth.at(today).accounts) (a.account.id, a.balance)],
    'transactions': ledger.transactions,
  };
}
