import 'package:equatable/equatable.dart';

import '../calendar_date.dart';
import '../ids.dart';
import '../journal/journal_entry.dart';
import 'account.dart';
import 'ledger.dart';
import 'ledger_exception.dart';

/// Journal entity and fields of a declared balance: the balance of an
/// account at the end of a day, entered by the user.
abstract final class BalanceFields {
  static const entity = 'balance';
  static const accountId = 'accountId';
  static const date = 'date';

  /// Signed, in cents: a balance can be negative (a loan).
  static const amount = 'amount';
}

/// The balance of [accountId] at the end of [date], as the user declared it.
class DeclaredBalance extends Equatable {
  const DeclaredBalance({required this.id, required this.accountId, required this.date, required this.amount});

  final String id;
  final String accountId;
  final CalendarDate date;
  final int amount;

  @override
  List<Object?> get props => [id, accountId, date, amount];
}

/// Identifier of the balance of [accountId] on [date]: computed, so that
/// declaring twice the same day replaces the balance, on one device or on
/// two.
String balanceId(String accountId, CalendarDate date) => derivedId('balance/$accountId/${date.encode()}');

/// The declared balances of a [Ledger] and their operations, apart from the
/// ledger's core. What they give (balances at any date, value variations)
/// is computed in `views/balances.dart`.
extension BalanceOperations on Ledger {
  /// The declared balances of [accountId], by date.
  List<DeclaredBalance> declaredBalancesOf(String accountId) => [
    for (final b in declaredBalances.values)
      if (b.accountId == accountId) b,
  ]..sort((a, b) => a.date.compareTo(b.date));

  /// Declares that [accountId] holds [amount] at the end of [date]. A
  /// balance already declared that day is replaced. Refused, with its
  /// reason: an unknown account; the detailed account, whose statements
  /// give the balance; a debts account, which has no balance of its own; a
  /// date after [today]. An archived account accepts one: declaring 0 takes
  /// it out of the wealth.
  Modification declareBalance(String accountId, CalendarDate date, int amount, {required CalendarDate today}) {
    _checkBalance(accountId, date, today);
    return Modification.set(BalanceFields.entity, balanceId(accountId, date), {
      BalanceFields.accountId: accountId,
      BalanceFields.date: date.encode(),
      BalanceFields.amount: amount,
      // A balance deleted that day comes back.
      deletedField: false,
    });
  }

  /// Modifies the declared balance [id]: its amount, and its date, which
  /// moves it to the balance of the new day (replaced if there is one).
  Modification updateBalance(String id, CalendarDate date, int amount, {required CalendarDate today}) {
    final existing = declaredBalances[id];
    if (existing == null) throw const LedgerException(LedgerError.unknownBalance);
    final declared = declareBalance(existing.accountId, date, amount, today: today);
    if (date == existing.date) return declared;
    return Modification([...declared.changes, FieldChange(BalanceFields.entity, id, deletedField, true)]);
  }

  /// Deletes the declared balance [id], whatever its account has become.
  Modification deleteBalance(String id) {
    if (!declaredBalances.containsKey(id)) throw const LedgerException(LedgerError.unknownBalance);
    return Modification.delete(BalanceFields.entity, id);
  }

  void _checkBalance(String accountId, CalendarDate date, CalendarDate today) {
    final account = accounts[accountId];
    if (account == null) throw const LedgerException(LedgerError.unknownAccount);
    if (account.isDetailed) throw const LedgerException(LedgerError.balanceOnDetailedAccount);
    if (account.type == AccountType.debts) throw const LedgerException(LedgerError.balanceOnDebtsAccount);
    if (date.isAfter(today)) throw const LedgerException(LedgerError.balanceInFuture);
  }
}
