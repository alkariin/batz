import 'package:equatable/equatable.dart';

import '../calendar_date.dart';
import 'category.dart';

/// Journal entity and fields of a transaction.
abstract final class TransactionFields {
  static const entity = 'transaction';
  static const accountId = 'accountId';
  static const date = 'date';
  static const amount = 'amount';
  static const counterpartAccountId = 'counterpartAccountId';
  static const description = 'description';
  static const note = 'note';
  static const status = 'status';

  /// The bank's text of an imported line: immutable.
  static const rawText = 'rawText';

  /// The statement an imported line comes from, and its rank in it (from 0).
  static const statementId = 'statementId';
  static const statementRank = 'statementRank';
}

/// Journal entity and fields of a transaction line: its category and the
/// period it concerns. A transaction has one line, or several when the user
/// splits it between categories; its lines add up to its amount.
abstract final class LineFields {
  static const entity = 'transactionLine';
  static const transactionId = 'transactionId';
  static const categoryId = 'categoryId';
  static const amount = 'amount';
  static const periodStart = 'periodStart';
  static const periodEnd = 'periodEnd';

  /// The line of the expense a refund is attached to.
  static const refundedLineId = 'refundedLineId';
}

/// What the journal records of a transaction's validation: an imported line
/// is to validate until the user validates it; a manual entry is validated
/// at once. « Proposée » and « à compléter » are not stored: they are
/// deduced from the rules of the year.
enum TransactionStatus { toValidate, validated }

/// The type of a transaction, deduced, never stored.
enum TransactionKind { expense, refund, income, transfer }

/// Whether money enters or leaves the account.
enum Direction { inflow, outflow }

/// The direction a manual entry takes by default in a category of
/// [nature]: out of the account for an expense, in for an income. The user
/// reverses it to enter a refund.
Direction defaultDirection(CategoryNature nature) =>
    nature == CategoryNature.expense ? Direction.outflow : Direction.inflow;

/// The signed amount of [cents] (not negative) in [direction].
int signedAmount(int cents, Direction direction) => direction == Direction.outflow ? -cents : cents;

class TransactionLine extends Equatable {
  const TransactionLine({
    required this.id,
    required this.transactionId,
    required this.categoryId,
    required this.amount,
    required this.periodStart,
    required this.periodEnd,
    this.refundedLineId,
  });

  final String id;
  final String transactionId;

  /// Null while not classified. For a refund attached to an expense, its
  /// own category: the one it gets back if the link breaks.
  final String? categoryId;
  final int amount;
  final CalendarDate periodStart;
  final CalendarDate periodEnd;

  /// For a refund, the line of the expense it is attached to: while the link
  /// holds, it takes the category and the period of that line.
  final String? refundedLineId;

  @override
  List<Object?> get props => [id, transactionId, categoryId, amount, periodStart, periodEnd, refundedLineId];
}

class LedgerTransaction extends Equatable {
  const LedgerTransaction({
    required this.id,
    required this.accountId,
    required this.date,
    required this.amount,
    this.counterpartAccountId,
    this.description = '',
    this.note = '',
    this.status = TransactionStatus.validated,
    this.rawText,
    this.statementId,
    this.statementRank,
    this.lines = const [],
  });

  final String id;
  final String accountId;

  /// Payment date.
  final CalendarDate date;

  /// Signed, in cents: negative when money leaves [accountId].
  final int amount;

  /// The other account of a transfer.
  final String? counterpartAccountId;
  final String description;
  final String note;
  final TransactionStatus status;

  /// The bank's text, for an imported line.
  final String? rawText;
  final String? statementId;
  final int? statementRank;
  final List<TransactionLine> lines;

  bool get isTransfer => counterpartAccountId != null;

  /// A line of an imported statement.
  bool get isImported => statementId != null;

  bool get isValidated => status == TransactionStatus.validated;

  /// Split between several categories: more than one line.
  bool get isSplit => lines.length > 1;

  /// The main line: the only one, or the largest of a split transaction
  /// (the ledger keeps the lines by amount, largest first).
  TransactionLine? get line => lines.isEmpty ? null : lines.first;

  LedgerTransaction withLines(List<TransactionLine> lines) => LedgerTransaction(
    id: id,
    accountId: accountId,
    date: date,
    amount: amount,
    counterpartAccountId: counterpartAccountId,
    description: description,
    note: note,
    status: status,
    rawText: rawText,
    statementId: statementId,
    statementRank: statementRank,
    lines: lines,
  );

  @override
  List<Object?> get props => [
    id,
    accountId,
    date,
    amount,
    counterpartAccountId,
    description,
    note,
    status,
    rawText,
    statementId,
    statementRank,
    lines,
  ];
}

/// What the user enters for an expense or an income: an amount
/// without sign and a direction.
class EntryDraft {
  const EntryDraft({
    required this.accountId,
    required this.date,
    required this.cents,
    required this.direction,
    required this.categoryId,
    this.description = '',
    this.note = '',
    this.periodStart,
    this.periodEnd,
    this.refundedLineId,
    this.lines = const [],
  });

  final String accountId;
  final CalendarDate date;

  /// The amount, without sign.
  final int cents;
  final Direction direction;

  /// Required, except for a refund attached to an expense
  /// ([refundedLineId]), whose own category is that of the expense when its
  /// year has one of the same name.
  final String? categoryId;
  final String description;
  final String note;

  /// The period the payment concerns; the payment date when null.
  final CalendarDate? periodStart;
  final CalendarDate? periodEnd;

  /// The line of the expense this entry refunds: it must be money coming
  /// in; its period is then its payment date.
  final String? refundedLineId;

  /// The lines of a split entry, when given: they replace [categoryId] and
  /// the period, add up to [cents], and cannot refund an expense.
  final List<LineDraft> lines;
}

/// A line the user enters for a transaction split between categories: its
/// category, its amount without sign (the transaction's sign applies) and
/// the period it concerns (the payment date when null). [id] is the line's
/// own, kept when the transaction is modified, or a new one.
class LineDraft extends Equatable {
  const LineDraft({required this.id, required this.categoryId, required this.cents, this.periodStart, this.periodEnd});

  final String id;
  final String categoryId;
  final int cents;
  final CalendarDate? periodStart;
  final CalendarDate? periodEnd;

  @override
  List<Object?> get props => [id, categoryId, cents, periodStart, periodEnd];
}

/// What the user enters for a transfer between two accounts.
class TransferDraft {
  const TransferDraft({
    required this.fromAccountId,
    required this.toAccountId,
    required this.date,
    required this.cents,
    this.description = '',
    this.note = '',
  });

  final String fromAccountId;
  final String toAccountId;
  final CalendarDate date;

  /// The amount, without sign.
  final int cents;
  final String description;
  final String note;
}
