import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/transaction.dart';
import '../../l10n/app_localizations.dart';

String kindText(AppLocalizations l, TransactionKind? kind) => switch (kind) {
  TransactionKind.expense => l.kindExpense,
  TransactionKind.refund => l.kindRefund,
  TransactionKind.income => l.kindIncome,
  TransactionKind.transfer => l.kindTransfer,
  null => l.kindUnclassified,
};

String accountName(Ledger ledger, String? id) => ledger.accounts[id]?.name ?? '?';

/// The accounts of [t]: one name, or "from → to" for a transfer.
String accountsText(AppLocalizations l, Ledger ledger, LedgerTransaction t) => t.isTransfer
    ? l.transferAccounts(accountName(ledger, t.accountId), accountName(ledger, t.counterpartAccountId))
    : accountName(ledger, t.accountId);

/// The category of [t], or those of the lines of a split transaction
/// joined by « + »; null when it has none.
String? categoriesText(Ledger ledger, LedgerTransaction t) {
  final categories = ledger.categoriesOf(t);
  return categories.isEmpty ? null : categories.map((c) => c.name).join(' + ');
}

/// The main label of [t] in a list: its description, or else its
/// categories, or else its type.
String titleText(AppLocalizations l, Ledger ledger, LedgerTransaction t) {
  if (t.description.isNotEmpty) return t.description;
  return categoriesText(ledger, t) ?? kindText(l, ledger.kindOf(t));
}

String statusText(AppLocalizations l, StatusFilter status) => switch (status) {
  StatusFilter.toValidate => l.statusToValidate,
  StatusFilter.toComplete => l.statusToComplete,
  StatusFilter.proposed => l.statusProposed,
  StatusFilter.validated => l.statusValidated,
};
