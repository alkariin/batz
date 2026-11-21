import '../calendar_date.dart';

/// Why the domain refuses an operation. The app turns each reason into a
/// message for the user.
enum LedgerError {
  nameRequired,
  secondDetailedAccount,
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

  // Import of a statement (phase 3).
  accountNotDetailed,
  statementOtherFormat,
  statementAlreadyImported,
  statementOtherAccount,
  statementNotContiguous,
  statementSumMismatch,
  statementTooLarge,
  statementNotLast,
  unknownStatement,
  importedTransaction,

  // Mapping rules (phase 3).
  unknownRule,
  ruleKeywordsRequired,
  ruleKeywordInvalid,
  ruleTargetRequired,
  rulePeriodInvalid,
  categoryUsedByRules,

  // Redistribution rules (phase 4).
  unknownRedistribution,
  redistributionSameCategory,
  redistributionNotLeaf,
  redistributionNatureMismatch,
  redistributionPercentInvalid,
  redistributionDuplicate,
  redistributionTargetIsSource,
  redistributionSourceIsTarget,
  redistributionOverHundred,
  categoryUsedByRedistributions,

  // Refunds attached to an expense (phase 4).
  refundNotInflow,
  refundIsTransfer,
  refundTargetNotExpense,

  // Shares to classify (phase 4).
  shareNatureMismatch,
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

/// A statement is refused as a whole, nothing written (specification, 4.4),
/// with what was expected and what the statement holds when the reason
/// compares them.
class StatementRefusedException extends LedgerException {
  const StatementRefusedException(
    super.error, {
    this.expectedStart,
    this.foundStart,
    this.expectedOpening,
    this.foundOpening,
    this.expectedIban,
    this.foundIban,
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

  @override
  String toString() =>
      'StatementRefusedException: ${error.name}'
      '${expectedStart == null ? '' : ' (start $foundStart, expected $expectedStart)'}'
      '${expectedOpening == null ? '' : ' (opening $foundOpening, expected $expectedOpening)'}'
      '${expectedIban == null ? '' : ' (IBAN $foundIban, expected $expectedIban)'}';
}
