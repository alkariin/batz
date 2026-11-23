/// The wealth: the net wealth at any date, its monthly curve, and the
/// table that explains, year by year and to the cent, why it changed.
///
/// Computed at each load, never stored: the journal holds only the declared
/// balances and the debts. The wealth at a date is the balance of every
/// account that has one at that date (one calculation, `balances.dart`),
/// plus the debts that count that day. Every line of the table is computed
/// for itself, the change of the wealth too; the tests check on random data
/// that they add up. The rules are described in docs/features.md, « Wealth
/// ».
library;

import 'package:equatable/equatable.dart';

import '../calendar_date.dart';
import '../ledger/account.dart';
import '../ledger/balance.dart';
import '../ledger/debt.dart';
import '../ledger/ledger.dart';
import '../ledger/statement.dart';
import 'balances.dart';
import 'year_view.dart';

/// One account in the wealth at a date.
class AccountWealth {
  const AccountWealth({
    required this.account,
    required this.balance,
    required this.lastPointDate,
    required this.lastDeclared,
    required this.lastStatement,
    required this.isOld,
  });

  final Account account;

  /// The balance at the end of the date; null while the account has none:
  /// it is outside the wealth.
  final int? balance;

  /// The date of the point the balance starts from.
  final CalendarDate? lastPointDate;

  /// The latest balance declared at or before the date.
  final DeclaredBalance? lastDeclared;

  /// The latest statement that ended at or before the date: its closing
  /// balance is the bank's.
  final Statement? lastStatement;

  /// Whether its last declared balance is more than six months
  /// old.
  final bool isOld;

  bool get inWealth => balance != null;
}

/// The wealth at the end of one day.
class WealthAt {
  WealthAt({required this.date, required List<AccountWealth> accounts, required this.debts})
    : accounts = List.unmodifiable(accounts);

  final CalendarDate date;

  /// Every account that can have a balance of its own (not a debts account),
  /// in the order of the accounts: those with a balance, archived or not
  /// unless an archived one is at 0, and those without one that are not
  /// archived.
  final List<AccountWealth> accounts;

  /// The debts that count that day, whether a debts account exists or
  /// not: what is owed to me minus what I owe.
  final int debts;

  /// The accounts with a balance, grouped by type: the groups in the order
  /// of their first account, the accounts in their order.
  Map<AccountType, List<AccountWealth>> get byType {
    final groups = <AccountType, List<AccountWealth>>{};
    for (final a in accounts) {
      if (a.inWealth) (groups[a.account.type] ??= []).add(a);
    }
    return groups;
  }

  /// The sum of the balances of each type.
  Map<AccountType, int> get totalsByType => {
    for (final MapEntry(key: type, value: accounts) in byType.entries)
      type: accounts.fold(0, (sum, a) => sum + a.balance!),
  };

  /// The accounts not archived without a balance: outside the wealth.
  List<Account> get withoutBalance => [
    for (final a in accounts)
      if (!a.inWealth) a.account,
  ];

  /// The net wealth: the balances plus the debts.
  int get total => accounts.fold(debts, (sum, a) => sum + (a.balance ?? 0));
}

/// The wealth at the end of a month of the curve.
class MonthWealth extends Equatable {
  const MonthWealth(this.year, this.month, this.date, this.amount);

  final int year;
  final int month;

  /// The last day of the month, or today for the current month.
  final CalendarDate date;
  final int amount;

  @override
  List<Object?> get props => [year, month, date, amount];
}

/// An amount of one account in a line of the table.
class AccountAmount extends Equatable {
  const AccountAmount(this.accountId, this.account, this.amount);

  final String accountId;

  /// Null for an account that no longer exists.
  final Account? account;
  final int amount;

  @override
  List<Object?> get props => [accountId, account, amount];
}

/// Why the wealth of one year changed, line by line. Each line is
/// computed for itself.
class WealthExplanation {
  WealthExplanation({
    required this.year,
    required this.start,
    required this.end,
    required this.hasView,
    required this.economicResult,
    required this.paidForOtherYears,
    required this.paidInOtherYears,
    required this.cashResult,
    required List<AccountAmount> valueVariations,
    required List<AccountAmount> addedAccounts,
    required this.openDebtsAtStart,
    required this.openDebtsAtEnd,
    required this.debtsAccountsMovements,
    required this.unclassified,
    required List<AccountAmount> outsideWealth,
    required this.wealthAtStart,
    required this.wealthAtEnd,
  }) : valueVariations = List.unmodifiable(valueVariations),
       addedAccounts = List.unmodifiable(addedAccounts),
       outsideWealth = List.unmodifiable(outsideWealth);

  final int year;

  /// The end of the year before, and the end of the year, or today for the
  /// current year.
  final CalendarDate start;
  final CalendarDate end;

  /// Whether the year has an annual view: a year before the first category
  /// tree has none, and its three results are zero.
  final bool hasView;

  /// Income minus expenses of the economic view of the year.
  final int economicResult;

  /// The period offsets of the year, signed as a result: paid this year for
  /// other years, and paid in other years for this one.
  final int paidForOtherYears;
  final int paidInOtherYears;

  /// Income minus expenses of the cash-flow view of the year.
  final int cashResult;

  /// Per account, the value variations of the balances declared in the
  /// year.
  final List<AccountAmount> valueVariations;

  /// Per account, its first balance, when it falls in the year: the account
  /// enters the wealth.
  final List<AccountAmount> addedAccounts;

  /// The debts that count at the end of the year before and of the year,
  /// and the movements of the year on the debts accounts (the transfers of
  /// a pure loan).
  final int openDebtsAtStart;
  final int openDebtsAtEnd;
  final int debtsAccountsMovements;

  /// « Non classé » of the cash-flow view of the year; for a year without
  /// view, every payment of the year outside transfers.
  final int unclassified;

  /// Per account, the opposite of its movements of the year while it had
  /// no balance yet, or once it no longer exists: what left the wealth
  /// followed, or came into it.
  final List<AccountAmount> outsideWealth;

  /// The wealth at [start] and at [end].
  final int wealthAtStart;
  final int wealthAtEnd;

  /// Paid this year for other years minus paid in other years for this
  /// one.
  int get periodOffsets => paidForOtherYears - paidInOtherYears;

  int get valueVariationsTotal => _sum(valueVariations);
  int get addedAccountsTotal => _sum(addedAccounts);

  /// The change of the open debts, less the movements on the debts
  /// accounts.
  int get debtsChange => openDebtsAtEnd - openDebtsAtStart - debtsAccountsMovements;
  int get outsideWealthTotal => _sum(outsideWealth);

  /// The wealth at the end minus the wealth at the start.
  int get wealthChange => wealthAtEnd - wealthAtStart;

  /// The lines after the cash-flow result, added to it: what the tests
  /// compare with [wealthChange]. The screen shows the lines, never this.
  int get explained =>
      cashResult + valueVariationsTotal + addedAccountsTotal + debtsChange + unclassified + outsideWealthTotal;

  static int _sum(List<AccountAmount> amounts) => amounts.fold(0, (sum, a) => sum + a.amount);
}

/// An account whose last declared balance is more than six months
/// old.
class OldBalance {
  const OldBalance(this.account, this.lastDeclared);

  final Account account;
  final DeclaredBalance lastDeclared;
}

/// The day six months before [date], the day clamped to the month: the
/// limit of an old balance.
CalendarDate sixMonthsBefore(CalendarDate date) {
  final months = date.year * 12 + date.month - 1 - 6;
  final year = months ~/ 12, month = months % 12 + 1;
  final day = date.day.clamp(1, CalendarDate.daysInMonth(year, month));
  return CalendarDate(year, month, day);
}

/// The wealth of a [Ledger] seen on [today].
class Wealth {
  Wealth(this.ledger, {required this.today});

  final Ledger ledger;
  final CalendarDate today;

  Balances get balances => ledger.balances;

  /// The annual views as of [today]: what is paid later does not count yet.
  late final YearViews views = YearViews(ledger, until: today);

  /// The net wealth at the end of [date]: the balance of every account that
  /// has one, plus the debts that count that day.
  int fortuneAt(CalendarDate date) {
    var total = ledger.openDebtsAt(date);
    for (final account in _accounts) {
      total += account.balanceAt(date) ?? 0;
    }
    return total;
  }

  /// The accounts that can have a balance: they exist and are not debts
  /// accounts.
  late final List<AccountBalances> _accounts = [
    for (final account in balances.all)
      if (account.hasOwnBalance) account,
  ];

  /// The wealth at the end of [date], account by account.
  WealthAt at(CalendarDate date) {
    final limit = sixMonthsBefore(date);
    final accounts = <AccountWealth>[];
    for (final account in ledger.sortedAccounts) {
      final balances = this.balances.of(account.id);
      if (!balances.hasOwnBalance) continue;
      final balance = balances.balanceAt(date);
      // An archived account leaves the list once its balance is 0: it is
      // still in the settings of accounts.
      if (account.archived && (balance ?? 0) == 0) continue;
      DeclaredBalance? lastDeclared;
      for (final point in balances.points) {
        if (point.date.isAfter(date)) break;
        if (point.declared case final declared?) lastDeclared = declared;
      }
      Statement? lastStatement;
      for (final statement in ledger.statementsOf(account.id)) {
        if (!statement.periodEnd.isAfter(date)) lastStatement = statement;
      }
      accounts.add(
        AccountWealth(
          account: account,
          balance: balance,
          lastPointDate: balances.lastPointDateAt(date),
          lastDeclared: lastDeclared,
          lastStatement: lastStatement,
          isOld: _remindable(account) && lastDeclared != null && lastDeclared.date.isBefore(limit),
        ),
      );
    }
    return WealthAt(date: date, accounts: accounts, debts: ledger.openDebtsAt(date));
  }

  /// The first day the wealth holds something: the first balance of an
  /// account, or the first day a debt counts. Null when there is none.
  late final CalendarDate? firstDate = () {
    CalendarDate? first;
    void consider(CalendarDate date) {
      if (first == null || date.isBefore(first!)) first = date;
    }

    for (final account in _accounts) {
      if (account.firstPoint case final point?) consider(point.date);
    }
    for (final debt in ledger.debts.values) {
      final end = debt.end;
      if (end == null || debt.start.isBefore(end)) consider(debt.start);
    }
    return first;
  }();

  /// The years that have a table: from the first year the wealth holds
  /// something to the current year.
  List<int> get years {
    final first = firstDate;
    if (first == null || first.isAfter(today)) return const [];
    return [for (var year = first.year; year <= today.year; year++) year];
  }

  /// The wealth at the end of each month, from the month of [firstDate] to
  /// the current one, whose value is today's.
  late final List<MonthWealth> monthly = () {
    final first = firstDate;
    if (first == null || first.isAfter(today)) return const <MonthWealth>[];
    return [
      for (var m = first.year * 12 + first.month - 1; m <= today.year * 12 + today.month - 1; m++)
        () {
          final year = m ~/ 12, month = m % 12 + 1;
          final last = CalendarDate(year, month, CalendarDate.daysInMonth(year, month));
          final date = last.isAfter(today) ? today : last;
          return MonthWealth(year, month, date, fortuneAt(date));
        }(),
    ];
  }();

  /// The table that explains the change of the wealth in [year], up to
  /// today for the current year.
  WealthExplanation explain(int year) => _tables.putIfAbsent(year, () => _explain(year));

  final _tables = <int, WealthExplanation>{};

  WealthExplanation _explain(int year) {
    final start = CalendarDate(year - 1, 12, 31);
    final last = CalendarDate(year, 12, 31);
    final end = last.isAfter(today) ? today : last;

    // The three results, from the annual views of the year.
    final cash = views.of(year, ViewKind.cash), economic = views.of(year, ViewKind.economic);

    // Value variations and accounts added: from the points of the year.
    final variations = <AccountAmount>[], added = <AccountAmount>[];
    for (final account in _accounts) {
      var variation = 0;
      var any = false;
      for (var i = 0; i < account.points.length; i++) {
        final point = account.points[i];
        if (!point.date.isAfter(start) || point.date.isAfter(end)) continue;
        if (i == 0) {
          added.add(AccountAmount(account.accountId, account.account, point.amount));
        } else {
          variation += account.variationAt(i)!;
          any = true;
        }
      }
      if (any) variations.add(AccountAmount(account.accountId, account.account, variation));
    }

    // The movements of the year: on the debts accounts, and on accounts
    // without a balance yet or that no longer exist.
    var debtsMovements = 0;
    final outside = <AccountAmount>[];
    for (final account in balances.all) {
      final movements = account.movementsIn(start, end);
      if (movements.isEmpty) continue;
      if (account.account?.type == AccountType.debts) {
        debtsMovements += movements.fold(0, (sum, m) => sum + m.amount);
        continue;
      }
      final first = account.hasOwnBalance ? account.firstPoint?.date : null;
      var sum = 0;
      var any = false;
      for (final movement in movements) {
        // A movement counts in the wealth once the account has a balance
        // before its day; one of the day of the first balance is part of it.
        if (first != null && movement.date.isAfter(first)) continue;
        sum += movement.amount;
        any = true;
      }
      if (any) outside.add(AccountAmount(account.accountId, account.account, -sum));
    }

    // « Non classé »: that of the cash-flow view; without a view, every
    // payment outside transfers.
    final int unclassified;
    if (cash == null) {
      var paid = 0;
      for (final t in ledger.transactions.values) {
        if (t.date.isAfter(start) && !t.date.isAfter(end) && balances.counterpartOf(t) == null) paid += t.amount;
      }
      unclassified = paid;
    } else {
      unclassified = cash.unclassified.total;
    }

    return WealthExplanation(
      year: year,
      start: start,
      end: end,
      hasView: cash != null,
      economicResult: economic?.savings.total ?? 0,
      paidForOtherYears: economic?.paidForOtherYears ?? 0,
      paidInOtherYears: economic?.paidInOtherYears ?? 0,
      cashResult: cash?.savings.total ?? 0,
      valueVariations: variations,
      addedAccounts: added,
      openDebtsAtStart: ledger.openDebtsAt(start),
      openDebtsAtEnd: ledger.openDebtsAt(end),
      debtsAccountsMovements: debtsMovements,
      unclassified: unclassified,
      outsideWealth: outside,
      wealthAtStart: fortuneAt(start),
      wealthAtEnd: fortuneAt(end),
    );
  }

  /// The accounts whose last declared balance is more than six months old
  /// at [today]: not archived, neither detailed nor a debts account. An
  /// account without a declared balance is not one.
  List<OldBalance> get oldBalances {
    final limit = sixMonthsBefore(today);
    return [
      for (final account in ledger.sortedAccounts)
        if (_remindable(account))
          if (balances.of(account.id).lastDeclared case final last? when last.date.isBefore(limit))
            OldBalance(account, last),
    ];
  }

  static bool _remindable(Account account) =>
      !account.archived && !account.isDetailed && account.type != AccountType.debts;
}

final _wealth = Expando<Map<CalendarDate, Wealth>>('wealth');

extension LedgerWealth on Ledger {
  /// The wealth of this ledger seen on [today], computed when first asked
  /// for and kept as long as the ledger.
  Wealth wealth(CalendarDate today) => (_wealth[this] ??= {}).putIfAbsent(today, () => Wealth(this, today: today));
}
