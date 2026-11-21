import '../journal/journal_entry.dart';
import '../ledger/ledger.dart';
import '../ledger/ledger_exception.dart';
import '../ledger/share_classification.dart';
import 'year_view.dart';

/// Answering the shares to classify (decision H5 of phase 4).
extension ShareOperations on Ledger {
  /// Classifies the shares of the lines [lineIds] that fall in [year] in
  /// [categoryId], a category of that year which can hold transactions and
  /// has the nature of their category of origin: one modification for a
  /// whole group or for one line. The answer is kept per line and year
  /// (principle 7: a computed identifier), with the category of origin it
  /// was given for. A year whose tree is still the copy to come gets it in
  /// the same modification, as with a first transaction (H5).
  Modification classifyShares(int year, Iterable<String> lineIds, String categoryId) {
    final tree = views.treeOf(year);
    if (tree == null) throw const LedgerException(LedgerError.noTree);
    if (!tree.canHoldTransactions(categoryId)) throw const LedgerException(LedgerError.categoryNotAssignable);
    final nature = tree.natureOf(categoryId);
    final changes = <FieldChange>[];
    for (final lineId in lineIds.toSet()) {
      final origin = views.originOf(lineId);
      if (origin == null) throw const LedgerException(LedgerError.unknownTransaction);
      if (trees[origin.year]!.natureOf(origin.id) != nature) {
        throw const LedgerException(LedgerError.shareNatureMismatch);
      }
      for (final field in {
        ShareClassificationFields.lineId: lineId,
        ShareClassificationFields.year: year,
        ShareClassificationFields.categoryId: categoryId,
        ShareClassificationFields.originCategoryId: origin.id,
      }.entries) {
        changes.add(
          FieldChange(ShareClassificationFields.entity, shareClassificationId(lineId, year), field.key, field.value),
        );
      }
    }
    if (changes.isEmpty) throw const LedgerException(LedgerError.unknownTransaction);
    return Modification([...changes, ...treeChangesFor(year)]);
  }

  /// The number of shares waiting for an answer: one per line and year.
  int get pendingShareCount => views.pendingShares.fold(0, (sum, group) => sum + group.shares.length);
}
