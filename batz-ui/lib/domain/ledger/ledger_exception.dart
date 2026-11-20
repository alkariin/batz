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
