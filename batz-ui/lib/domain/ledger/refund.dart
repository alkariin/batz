import '../journal/journal_entry.dart';
import 'ledger.dart';
import 'ledger_exception.dart';
import 'transaction.dart';

/// Refunds attached to an expense, apart from the ledger's core. The
/// journal keeps only the link, on the line of the refund; while it leads
/// to a validated expense, the refund takes its category and its period
/// ([Ledger.refundedExpenseOf]).
extension RefundOperations on Ledger {
  /// Attaches the refund [transactionId] to the expense line
  /// [expenseLineId]: money that came in, not a transfer, entered by hand or
  /// imported, to a validated expense of any account and any year. An
  /// imported line to validate is validated by it. The line keeps a category
  /// of its own, the one of the same name as the expense's in the tree of
  /// its payment year when there is one, and its payment date as period:
  /// they serve if the link breaks. A refund is not split: its main line
  /// takes the whole amount, its other lines are deleted.
  Modification attachRefund(String transactionId, String expenseLineId) {
    final t = transactions[transactionId];
    if (t == null) throw const LedgerException(LedgerError.unknownTransaction);
    if (t.isValidated && t.isTransfer) throw const LedgerException(LedgerError.refundIsTransfer);
    if (t.amount <= 0) throw const LedgerException(LedgerError.refundNotInflow);
    final expense = linesById[expenseLineId];
    if (expense == null || !isExpenseLine(expense.transaction, expense.line)) {
      throw const LedgerException(LedgerError.refundTargetNotExpense);
    }
    final line = t.line;
    final lineId = line?.id ?? Ledger.fallbackLineId(t.id);
    return Modification([
      if (!t.isValidated)
        FieldChange(TransactionFields.entity, t.id, TransactionFields.status, TransactionStatus.validated.name),
      if (t.counterpartAccountId != null)
        FieldChange(TransactionFields.entity, t.id, TransactionFields.counterpartAccountId, null),
      for (final field in {
        LineFields.transactionId: t.id,
        LineFields.categoryId: ownRefundCategory(
          t.date.year,
          expense.line.categoryId,
          t.isValidated ? line?.categoryId : null,
        ),
        LineFields.amount: t.amount,
        LineFields.periodStart: t.date.encode(),
        LineFields.periodEnd: t.date.encode(),
        LineFields.refundedLineId: expenseLineId,
        // A line deleted with its statement, or by a transfer, comes back.
        if (line == null) deletedField: false,
      }.entries)
        FieldChange(LineFields.entity, lineId, field.key, field.value),
      for (final other in t.lines)
        if (other.id != lineId) FieldChange(LineFields.entity, other.id, deletedField, true),
    ]);
  }

  /// Attaches the imported line [transactionId] to the expense line
  /// [expenseLineId] and sets its description and note, in one
  /// modification: the third choice of the validation screen.
  Modification validateAsRefund(
    String transactionId,
    String expenseLineId, {
    required String description,
    required String note,
  }) => Modification([
    ...attachRefund(transactionId, expenseLineId).changes,
    FieldChange(TransactionFields.entity, transactionId, TransactionFields.description, description.trim()),
    FieldChange(TransactionFields.entity, transactionId, TransactionFields.note, note.trim()),
  ]);

  /// Detaches the refund [transactionId]: its line gets back its own
  /// category and its date.
  Modification detachRefund(String transactionId) {
    final line = transactions[transactionId]?.line;
    if (line == null || line.refundedLineId == null) throw const LedgerException(LedgerError.unknownTransaction);
    return Modification.set(LineFields.entity, line.id, {LineFields.refundedLineId: null});
  }

  /// The refunds attached to the lines of [expense] whose link holds, by
  /// date.
  List<LedgerTransaction> refundsOf(LedgerTransaction expense) {
    if (!expense.isSplit) return expense.line == null ? const [] : refundsByExpenseLine[expense.line!.id] ?? const [];
    final refunds = {for (final line in expense.lines) ...?refundsByExpenseLine[line.id]}.toList();
    return refunds..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  }

  /// The net cost of [expense]: its amount plus its refunds (negative for a
  /// cost).
  int netCostOf(LedgerTransaction expense) => refundsOf(expense).fold(expense.amount, (sum, r) => sum + r.amount);

  /// The expense line that the refund [transaction] is attached to, while
  /// the link holds.
  LineOf? expenseOf(LedgerTransaction transaction) {
    final line = transaction.line;
    return line == null ? null : refundedExpenseOf(transaction, line);
  }

  /// The validated expense lines a refund can be attached to, found by
  /// [text] (words of the description, the note, the bank text, the
  /// category, the accounts or the amount, as the transactions list
  /// searches), most recent first; each line of a split expense apart.
  List<LineOf> refundTargets(String text) => [
    for (final t in search(TransactionQuery(text: text)))
      for (final line in t.lines)
        if (isExpenseLine(t, line)) (line: line, transaction: t),
  ];

  /// The validated refunds whose link no longer leads to a validated
  /// expense: the expense or its statement was deleted, it was classified
  /// otherwise, or the refund is no longer money that came in. They count
  /// with their own category and date, and are listed in the tasks until
  /// they are detached or attached again.
  List<LedgerTransaction> get brokenRefunds =>
      [
        for (final t in transactions.values)
          if (t.isValidated && !t.isTransfer)
            for (final line in t.lines)
              if (line.refundedLineId != null && refundedExpenseOf(t, line) == null) t,
      ]..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
}
