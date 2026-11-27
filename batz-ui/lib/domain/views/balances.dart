/// The balances of the accounts.
///
/// Computed at each load from what the user entered, never stored: the
/// journal holds only the declared balances. One calculation gives the
/// balance of an account at any date: the last point at or before that date,
/// plus the movements dated after it, up to that date included. The expected
/// balance of a declared balance, and its value variation, are that same
/// calculation from the point before. Every date is the end of its day. The
/// rules are described in docs/features.md, « Wealth ».
library;

import 'package:equatable/equatable.dart';

import '../calendar_date.dart';
import '../ledger/account.dart';
import '../ledger/balance.dart';
import '../ledger/ledger.dart';
import '../ledger/statement.dart';
import '../ledger/transaction.dart';

/// A known balance of an account at the end of a day: a declared balance,
/// or the opening balance of the account's first statement, the day before
/// it starts.
class BalancePoint extends Equatable {
  BalancePoint.declared(DeclaredBalance this.declared)
    : date = declared.date,
      amount = declared.amount,
      statement = null;

  BalancePoint.statement(Statement this.statement)
    : date = statement.periodStart.addDays(-1),
      amount = statement.openingBalance,
      declared = null;

  final CalendarDate date;
  final int amount;

  /// The declared balance, for a point the user entered.
  final DeclaredBalance? declared;

  /// The first statement, for the point it gives.
  final Statement? statement;

  bool get isDeclared => declared != null;

  @override
  List<Object?> get props => [date, amount, declared, statement];
}

/// What a transaction changes on one account: its amount on its own
/// account, its opposite on the counterpart of a transfer.
class Movement extends Equatable {
  const Movement(this.transaction, this.amount, {required this.arrival});

  final LedgerTransaction transaction;

  /// Signed as it changes the account: positive when money comes in.
  final int amount;

  /// Whether the account is the counterpart of the transfer: the money
  /// arrives there.
  final bool arrival;

  CalendarDate get date => transaction.date;

  @override
  List<Object?> get props => [transaction.id, amount, arrival];
}

/// One point of an account's history, with what the point before it led
/// to expect.
class BalanceStep {
  const BalanceStep({required this.point, required this.expected, required this.movements});

  final BalancePoint point;

  /// The balance expected that day: the point before plus the movements
  /// since; null for the first point, which brings the account into the
  /// wealth.
  final int? expected;

  /// The movements since the point before, up to this one's day included;
  /// for the first point, those before it, which it includes.
  final List<Movement> movements;

  /// The value variation: the declared balance minus the balance
  /// expected, dated the day of the declaration.
  int? get variation => expected == null ? null : point.amount - expected!;
}

/// The balances of one account.
class AccountBalances {
  AccountBalances._(this.accountId, this.account, List<BalancePoint> points, List<Movement> movements, this.ignored)
    : points = List.unmodifiable(points),
      movements = List.unmodifiable(movements),
      _keys = [for (final m in movements) _key(m.date)] {
    var sum = 0;
    for (final m in movements) {
      _sums.add(sum += m.amount);
    }
  }

  final String accountId;

  /// Null when the account no longer exists (deleted on another device, or
  /// not arrived yet): its movements are outside the wealth.
  final Account? account;

  /// The points of the account, by date; on the same day, the point of the
  /// first statement before a declared balance. None for an account that
  /// has no balance of its own: unknown, or a debts account.
  final List<BalancePoint> points;

  /// Every movement of the account, by date then transaction.
  final List<Movement> movements;

  /// Declared balances that do not count: those of a debts account or of an
  /// account that no longer exists, which only a merge can leave.
  final List<DeclaredBalance> ignored;

  final List<int> _keys;
  final _sums = <int>[];

  /// Whether the account can have a balance: it exists and is not a debts
  /// account, whose debts table gives the wealth instead.
  bool get hasOwnBalance => account != null && account!.type != AccountType.debts;

  BalancePoint? get firstPoint => points.isEmpty ? null : points.first;
  BalancePoint? get lastPoint => points.isEmpty ? null : points.last;

  /// The last declared balance, for the reminder of old balances.
  DeclaredBalance? get lastDeclared {
    for (final point in points.reversed) {
      if (point.declared case final declared?) return declared;
    }
    return null;
  }

  /// The balance at the end of [date]: the last point at or before it, plus
  /// the movements dated after that point, up to [date] included. Null
  /// before the first point: the account is not in the wealth yet.
  int? balanceAt(CalendarDate date) {
    final index = _lastPointAt(date);
    if (index < 0) return null;
    return _from(index, date);
  }

  /// The date of the point [balanceAt] starts from, null before the first.
  CalendarDate? lastPointDateAt(CalendarDate date) {
    final index = _lastPointAt(date);
    return index < 0 ? null : points[index].date;
  }

  /// The balance expected at the point [index] from the point before it,
  /// with the same calculation as [balanceAt]; null for the first point.
  int? expectedAt(int index) => index == 0 ? null : _from(index - 1, points[index].date);

  /// The value variation of the point [index]: null for the first point.
  int? variationAt(int index) => index == 0 ? null : points[index].amount - expectedAt(index)!;

  /// Point [index] plus the movements after its day, up to [date] included.
  int _from(int index, CalendarDate date) => points[index].amount + movementsBetween(points[index].date, date);

  int _lastPointAt(CalendarDate date) {
    for (var i = points.length - 1; i >= 0; i--) {
      if (!points[i].date.isAfter(date)) return i;
    }
    return -1;
  }

  /// The sum of the movements dated after [after] (excluded; from the first
  /// one when null) up to [upTo] included.
  int movementsBetween(CalendarDate? after, CalendarDate upTo) {
    final end = _sumUpTo(_key(upTo));
    return after == null ? end : end - _sumUpTo(_key(after));
  }

  /// The movements dated after [after] (excluded; from the first one when
  /// null) up to [upTo] included.
  List<Movement> movementsIn(CalendarDate? after, CalendarDate upTo) {
    final from = after == null ? 0 : _countUpTo(_key(after));
    final to = _countUpTo(_key(upTo));
    return from >= to ? const [] : movements.sublist(from, to);
  }

  /// The history of the account: each point, with the balance expected and
  /// the movements since the point before.
  List<BalanceStep> get history => [
    for (var i = 0; i < points.length; i++)
      BalanceStep(
        point: points[i],
        expected: expectedAt(i),
        movements: movementsIn(i == 0 ? null : points[i - 1].date, points[i].date),
      ),
  ];

  int _sumUpTo(int key) {
    final count = _countUpTo(key);
    return count == 0 ? 0 : _sums[count - 1];
  }

  /// How many movements are dated up to [key] included.
  int _countUpTo(int key) {
    var low = 0, high = _keys.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (_keys[middle] <= key) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }
}

int _key(CalendarDate date) => date.year * 10000 + date.month * 100 + date.day;

/// The balances of every account of a [Ledger], computed when first asked
/// for.
class Balances {
  Balances(this.ledger);

  final Ledger ledger;

  /// The other account of [transaction] when it is a transfer, validated or
  /// proposed: a line to validate counts as its rules propose it, as in the
  /// annual view.
  String? counterpartOf(LedgerTransaction transaction) {
    if (transaction.isValidated) return transaction.counterpartAccountId;
    final proposal = ledger.proposalOf(transaction);
    return proposal?.isTransfer ?? false ? proposal!.counterpartAccountId : null;
  }

  /// The balances of [accountId]; empty for an account without points nor
  /// movements.
  AccountBalances of(String accountId) =>
      _byAccount[accountId] ?? AccountBalances._(accountId, ledger.accounts[accountId], const [], const [], const []);

  /// Every account that exists or has movements, points or declared
  /// balances, by identifier.
  Iterable<AccountBalances> get all => _byAccount.values;

  late final Map<String, AccountBalances> _byAccount = _build();

  Map<String, AccountBalances> _build() {
    final movements = <String, List<Movement>>{};
    for (final t in ledger.transactions.values) {
      (movements[t.accountId] ??= []).add(Movement(t, t.amount, arrival: false));
      // The two lines of a transfer between detailed accounts each count on
      // their own account: neither arrives on the other.
      if (ledger.transferPairs.containsKey(t.id)) continue;
      if (counterpartOf(t) case final counterpart?) {
        (movements[counterpart] ??= []).add(Movement(t, -t.amount, arrival: true));
      }
    }
    final declared = <String, List<DeclaredBalance>>{};
    for (final balance in ledger.declaredBalances.values) {
      (declared[balance.accountId] ??= []).add(balance);
    }
    final firstStatements = <String, Statement>{};
    for (final statement in ledger.statements.values) {
      final first = firstStatements[statement.accountId];
      if (first == null ||
          statement.periodStart.isBefore(first.periodStart) ||
          (statement.periodStart == first.periodStart && statement.id.compareTo(first.id) < 0)) {
        firstStatements[statement.accountId] = statement;
      }
    }
    final ids = {...ledger.accounts.keys, ...movements.keys, ...declared.keys, ...firstStatements.keys}.toList()
      ..sort();
    return {for (final id in ids) id: _account(id, movements[id] ?? [], declared[id] ?? const [], firstStatements[id])};
  }

  AccountBalances _account(String id, List<Movement> movements, List<DeclaredBalance> declared, Statement? first) {
    final account = ledger.accounts[id];
    movements.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      final byId = a.transaction.id.compareTo(b.transaction.id);
      return byId != 0 ? byId : (a.arrival ? 1 : 0) - (b.arrival ? 1 : 0);
    });
    final counts = account != null && account.type != AccountType.debts;
    final points = <BalancePoint>[
      if (counts && first != null) BalancePoint.statement(first),
      if (counts)
        for (final balance in declared) BalancePoint.declared(balance),
    ];
    // By date; on the same day, the statement first (its opening is the
    // balance the bank printed), then declared balances by identifier.
    points.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      if (a.isDeclared != b.isDeclared) return a.isDeclared ? 1 : -1;
      return (a.declared?.id ?? '').compareTo(b.declared?.id ?? '');
    });
    final ignored = counts ? const <DeclaredBalance>[] : ([...declared]..sort((a, b) => a.date.compareTo(b.date)));
    return AccountBalances._(id, account, points, movements, ignored);
  }
}

final _balances = Expando<Balances>('balances');

extension LedgerBalances on Ledger {
  /// The balances of the accounts of this ledger, computed when first asked
  /// for and kept as long as the ledger: a new ledger is loaded after each
  /// write.
  Balances get balances => _balances[this] ??= Balances(this);
}
