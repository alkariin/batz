import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/journal/journal_entry.dart';
import '../domain/ledger/account.dart';
import '../domain/ledger/category.dart';
import '../domain/ledger/ledger.dart';
import '../domain/ledger/ledger_exception.dart';
import '../l10n/app_localizations.dart';
import 'ledger_cubit.dart';

String ledgerErrorText(AppLocalizations l, LedgerException e) => switch (e.error) {
  LedgerError.nameRequired => l.errorNameRequired,
  LedgerError.secondDetailedAccount => l.errorSecondDetailedAccount,
  LedgerError.unknownAccount => l.errorUnknownAccount,
  LedgerError.unknownCategory => l.errorUnknownCategory,
  LedgerError.categoryNameTaken => l.errorCategoryNameTaken,
  LedgerError.natureRequired => l.errorNatureRequired,
  LedgerError.treeExists => l.errorTreeExists,
  LedgerError.noTree => l.errorNoTree,
  LedgerError.categoryLoop => l.errorCategoryLoop,
  LedgerError.parentHasTransactions => l.errorParentHasTransactions(e.count),
  LedgerError.categoryHasChildren => l.errorCategoryHasChildren,
  LedgerError.categoryInUse => l.errorCategoryInUse(e.count),
  LedgerError.unknownTransaction => l.errorUnknownTransaction,
  LedgerError.amountRequired => l.errorAmountRequired,
  LedgerError.archivedAccount => l.errorArchivedAccount,
  LedgerError.detailedAccountManual => l.errorDetailedAccountManual,
  LedgerError.debtsAccountManual => l.errorDebtsAccountManual,
  LedgerError.categoryNotAssignable => l.errorCategoryNotAssignable,
  LedgerError.periodInvalid => l.errorPeriodInvalid,
  LedgerError.sameAccount => l.errorSameAccount,
};

String natureText(AppLocalizations l, CategoryNature nature) => switch (nature) {
  CategoryNature.income => l.natureIncome,
  CategoryNature.expense => l.natureExpense,
};

String detachReasonText(AppLocalizations l, DetachReason reason) => switch (reason) {
  DetachReason.loop => l.detachedLoop,
  DetachReason.missingParent => l.detachedMissingParent,
  DetachReason.parentInOtherYear => l.detachedParentInOtherYear,
  DetachReason.groupWithoutNature => l.detachedGroupWithoutNature,
  DetachReason.detachedAncestor => l.detachedAncestor,
};

String accountTypeText(AppLocalizations l, AccountType type) => switch (type) {
  AccountType.privateAccount => l.accountTypePrivateAccount,
  AccountType.savings => l.accountTypeSavings,
  AccountType.pillar3 => l.accountTypePillar3,
  AccountType.pillar2 => l.accountTypePillar2,
  AccountType.investments => l.accountTypeInvestments,
  AccountType.vehicle => l.accountTypeVehicle,
  AccountType.rentDeposit => l.accountTypeRentDeposit,
  AccountType.cash => l.accountTypeCash,
  AccountType.debts => l.accountTypeDebts,
  AccountType.other => l.accountTypeOther,
};

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Computes a modification from the current ledger and writes it. A refusal
/// of the domain is shown to the user and returns false; nothing is written.
Future<bool> applyToLedger(BuildContext context, Modification Function(Ledger ledger) build) async {
  final cubit = context.read<LedgerCubit>();
  final Modification modification;
  try {
    modification = build(cubit.state.ledger);
  } on LedgerException catch (e) {
    showMessage(context, ledgerErrorText(AppLocalizations.of(context), e));
    return false;
  }
  await cubit.write(modification);
  return true;
}
