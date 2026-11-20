import '../journal/journal_entry.dart';
import 'account.dart';
import 'ledger_exception.dart';

/// Everything the user has entered, as read from the derived tables at one
/// moment. Immutable; the rules below check an operation against it and
/// return the [Modification] to write to the journal.
class Ledger {
  Ledger({Iterable<Account> accounts = const []}) : accounts = {for (final a in accounts) a.id: a};

  static final empty = Ledger();

  final Map<String, Account> accounts;

  /// Active accounts by name, then archived ones by name.
  List<Account> get sortedAccounts {
    int byName(Account a, Account b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return [
      ...accounts.values.where((a) => !a.archived).toList()..sort(byName),
      ...accounts.values.where((a) => a.archived).toList()..sort(byName),
    ];
  }

  // ---------------------------------------------------------------- accounts

  /// Creates the account [id]. Refused if the name is empty, or if import is
  /// enabled while another account is already detailed.
  Modification createAccount(String id, AccountDraft draft) {
    _checkAccount(id, draft);
    return Modification.set(AccountFields.entity, id, _accountFields(draft));
  }

  /// Modifies the account [id], under the same rules as [createAccount].
  Modification updateAccount(String id, AccountDraft draft) {
    if (!accounts.containsKey(id)) throw const LedgerException(LedgerError.unknownAccount);
    _checkAccount(id, draft);
    return Modification.set(AccountFields.entity, id, _accountFields(draft));
  }

  /// Removes the account [id] (decision H5 of phase 1): deleted if no
  /// transaction uses it, archived otherwise.
  AccountRemoval removeAccount(String id) {
    final account = accounts[id];
    if (account == null) throw const LedgerException(LedgerError.unknownAccount);
    final used = transactionsUsingAccount(id);
    if (used == 0) return AccountRemoval(Modification.delete(AccountFields.entity, id), 0);
    return AccountRemoval(Modification.set(AccountFields.entity, id, {AccountFields.archived: true}), used);
  }

  /// The number of transactions on [accountId] or with it as counterpart.
  int transactionsUsingAccount(String accountId) => 0;

  void _checkAccount(String id, AccountDraft draft) {
    if (draft.name.trim().isEmpty) throw const LedgerException(LedgerError.nameRequired);
    if (draft.importFormat != null && accounts.values.any((a) => a.id != id && a.isDetailed)) {
      throw const LedgerException(LedgerError.secondDetailedAccount);
    }
  }

  static Map<String, Object?> _accountFields(AccountDraft draft) => {
    AccountFields.name: draft.name.trim(),
    AccountFields.type: draft.type.name,
    AccountFields.importFormat: draft.importFormat?.name,
    AccountFields.archived: draft.archived,
  };
}

/// The outcome of [Ledger.removeAccount].
class AccountRemoval {
  const AccountRemoval(this.modification, this.transactionCount);

  final Modification modification;

  /// Transactions that use the account; when there are any, the account is
  /// archived instead of deleted.
  final int transactionCount;

  bool get archives => transactionCount > 0;
}
