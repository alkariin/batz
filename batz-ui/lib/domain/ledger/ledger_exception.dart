import '../calendar_date.dart';

/// Why the domain refuses an operation. The app turns each reason into a
/// message for the user.
enum LedgerError {
  nameRequired,
  unknownAccount,
  unknownCategory,
  categoryNameTaken,
  natureRequired,
  treeExists,
  noTree,
  categoryLoop,
  parentHasTransactions,
  categoryHasChildren,
  categoryInUse,
  unknownTransaction,
  amountRequired,
  archivedAccount,
  detailedAccountManual,
  debtsAccountManual,
  categoryNotAssignable,
  periodInvalid,
  sameAccount,

  // A transaction split between categories.
  splitLineAmountInvalid,
  splitSumMismatch,
  splitRefund,

  // Import of a statement.
  accountNotDetailed,
  statementOtherFormat,
  statementAlreadyImported,
  statementOtherAccount,
  statementNotContiguous,
  statementSumMismatch,
  statementTooLarge,
  statementNotLast,
  statementNoNewLines,
  statementLinesBeforeFirst,
  statementImportedToday,
  statementBalanceRequired,
  statementBalanceMismatch,
  unknownStatement,
  importedTransaction,

  // Mapping rules.
  unknownRule,
  ruleKeywordsRequired,
  ruleKeywordInvalid,
  ruleTargetRequired,

  // Redistribution rules.
  unknownRedistribution,
  redistributionSameCategory,
  redistributionNotLeaf,
  redistributionNatureMismatch,
  redistributionPercentInvalid,
  redistributionAmountInvalid,
  redistributionPercentOrAmount,
  redistributionDuplicate,
  redistributionTargetIsSource,
  redistributionSourceIsTarget,
  redistributionOverHundred,
  categoryUsedByRedistributions,

  // Refunds attached to an expense.
  refundNotInflow,
  refundIsTransfer,
  refundTargetNotExpense,

  // Shares to classify.
  shareNatureMismatch,

  // Declared balances.
  unknownBalance,
  balanceOnDetailedAccount,
  balanceOnDebtsAccount,
  balanceInFuture,

  // Debts.
  unknownDebt,
  debtPersonRequired,
  debtPercentInvalid,
  debtAlreadyRepaid,
  debtTransactionIsTransfer,
  debtRepaymentDirection,
  debtReceivedBeforeEvent,
  debtSplitOutOfTotal,

  // Modules.
  moduleCategoryRequired,
  unknownSalarySheet,
  salaryGrossRequired,
  salaryNetNegative,
  salaryDeductionLabelRequired,
  salaryDeductionNegative,
  unknownTaxYear,
  taxBaseNegative,
  taxRateInvalid,
  taxCoefficientNegative,
  taxMarginalRateInvalid,
  unknownTripSheet,
  tripDaysInvalid,
  tripDateRequired,
  tripAmountRequired,
  unknownElectricityReading,
  electricityNegative,
  unknownSubscription,
  trancheEndBeforeStart,
  trancheOverlap,
}

/// A business rule refuses the operation; nothing was written.
class LedgerException implements Exception {
  const LedgerException(this.error, {this.count = 0});

  final LedgerError error;

  /// The number of records involved, when the reason names one (for
  /// instance the transactions that use a category).
  final int count;

  @override
  String toString() => 'LedgerException: ${error.name}${count == 0 ? '' : ' ($count)'}';
}

/// A statement is refused as a whole, nothing written, with what was
/// expected and what the statement holds when the reason compares them.
class StatementRefusedException extends LedgerException {
  const StatementRefusedException(
    super.error, {
    this.expectedStart,
    this.foundStart,
    this.expectedOpening,
    this.foundOpening,
    this.expectedIban,
    this.foundIban,
    this.expectedBalance,
    this.foundBalance,
    super.count,
  });

  /// For [LedgerError.statementNotContiguous]: the day after the previous
  /// statement and its closing balance, and those of the statement.
  final CalendarDate? expectedStart;
  final CalendarDate? foundStart;
  final int? expectedOpening;
  final int? foundOpening;

  /// For [LedgerError.statementOtherAccount].
  final String? expectedIban;
  final String? foundIban;

  /// For [LedgerError.statementBalanceMismatch]: the balance of the latest
  /// import plus the new lines ([count] of them), and the balance typed.
  /// For [LedgerError.statementLinesBeforeFirst], [foundStart] is the date
  /// of the earliest new line, [expectedStart] the start of the account's
  /// first statement.
  final int? expectedBalance;
  final int? foundBalance;

  @override
  String toString() =>
      'StatementRefusedException: ${error.name}'
      '${expectedStart == null ? '' : ' (start $foundStart, expected $expectedStart)'}'
      '${expectedOpening == null ? '' : ' (opening $foundOpening, expected $expectedOpening)'}'
      '${expectedIban == null ? '' : ' (IBAN $foundIban, expected $expectedIban)'}'
      '${expectedBalance == null ? '' : ' (balance $foundBalance, expected $expectedBalance)'}';
}
