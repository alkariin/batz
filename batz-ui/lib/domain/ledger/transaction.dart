import 'package:equatable/equatable.dart';

import '../calendar_date.dart';
import 'category.dart';

/// Journal entity and fields of a transaction (specification, 4.2).
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
/// period it concerns. The model allows several lines per transaction; the
/// app manages one.
abstract final class LineFields {
  static const entity = 'transactionLine';
  static const transactionId = 'transactionId';
  static const categoryId = 'categoryId';
  static const amount = 'amount';
  static const periodStart = 'periodStart';
  static const periodEnd = 'periodEnd';
}

/// What the journal records of a transaction's validation (principle 3 of
/// phase 3): an imported line is to validate until the user validates it; a
/// manual entry is validated at once. « Proposée » and « à compléter » are
/// not stored: they are deduced from the rules of the year.
enum TransactionStatus { toValidate, validated }

/// The type of a transaction, deduced, never stored (specification, 4.2).
enum TransactionKind { expense, refund, income, transfer }

/// Whether money enters or leaves the account (decision H3).
enum Direction { inflow, outflow }

/// The direction a manual entry takes by default in a category of [nature]
/// (decision H3): out of the account for an expense, in for an income. The
/// user reverses it to enter a refund.
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
  });

  final String id;
  final String transactionId;

  /// Null while not classified.
  final String? categoryId;
  final int amount;
  final CalendarDate periodStart;
  final CalendarDate periodEnd;

  @override
  List<Object?> get props => [id, transactionId, categoryId, amount, periodStart, periodEnd];
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

  /// The line the app manages.
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

/// What the user enters for an expense or an income (decision H3): an
/// amount without sign and a direction.
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
  });

  final String accountId;
  final CalendarDate date;

  /// The amount, without sign.
  final int cents;
  final Direction direction;
  final String categoryId;
  final String description;
  final String note;

  /// The period the payment concerns; the payment date when null.
  final CalendarDate? periodStart;
  final CalendarDate? periodEnd;
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

/// Cash-flow totals of one year: what was paid in it, by category
/// (specification, 4.2, "Vue trésorerie"). Transfers are left out.
class YearTotals {
  const YearTotals({
    required this.year,
    required this.byCategory,
    required this.income,
    required this.expenses,
    required this.unclassified,
  });

  final int year;

  /// Signed total of each category of the year's tree, groups included
  /// (a group adds up its children). Categories without any amount are
  /// absent.
  final Map<String, int> byCategory;

  /// Total of the income groups.
  final int income;

  /// Total of the expense groups: negative, refunds included.
  final int expenses;

  /// Lines without a category of the year's tree.
  final int unclassified;

  /// Income minus expenses.
  int get savings => income + expenses;
}
