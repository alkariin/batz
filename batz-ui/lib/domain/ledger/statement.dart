import 'package:equatable/equatable.dart';

import '../calendar_date.dart';
import '../ids.dart';
import '../journal/journal_entry.dart';

/// Journal entity and fields of an imported statement.
abstract final class StatementFields {
  static const entity = 'statement';
  static const accountId = 'accountId';
  static const format = 'format';
  static const iban = 'iban';
  static const periodStart = 'periodStart';
  static const periodEnd = 'periodEnd';
  static const openingBalance = 'openingBalance';
  static const closingBalance = 'closingBalance';

  /// SHA-256 of the PDF file: the server keeps the file under it.
  static const fingerprint = 'fingerprint';
}

/// A statement imported into a detailed account. Its lines are the
/// transactions whose `statementId` is its identifier.
class Statement extends Equatable {
  const Statement({
    required this.id,
    required this.accountId,
    required this.format,
    required this.iban,
    required this.periodStart,
    required this.periodEnd,
    required this.openingBalance,
    required this.closingBalance,
    required this.fingerprint,
  });

  final String id;
  final String accountId;
  final String format;

  /// The account's IBAN, without spaces.
  final String iban;
  final CalendarDate periodStart;
  final CalendarDate periodEnd;

  /// Signed, in cents.
  final int openingBalance;
  final int closingBalance;
  final String fingerprint;

  @override
  List<Object?> get props => [
    id,
    accountId,
    format,
    iban,
    periodStart,
    periodEnd,
    openingBalance,
    closingBalance,
    fingerprint,
  ];
}

/// Identifier of the statement of [fingerprint] imported into [accountId]:
/// computed, so that two devices importing the same file write the same
/// records.
String statementId(String accountId, String fingerprint) => derivedId('statement/$accountId/$fingerprint');

/// Identifier of the transaction of line [rank] (from 0) of a statement.
String importedTransactionId(String statementId, int rank) => derivedId('statement-line/$statementId/$rank');

/// What the server read in a statement file (`POST /api/v1/imports`).
class ExtractedStatement {
  const ExtractedStatement({
    required this.format,
    required this.iban,
    required this.currency,
    required this.periodStart,
    required this.periodEnd,
    required this.openingBalance,
    required this.closingBalance,
    required this.totalCredits,
    required this.totalDebits,
    required this.lines,
  });

  final String format;
  final String iban;
  final String currency;
  final CalendarDate periodStart;
  final CalendarDate periodEnd;
  final int openingBalance;
  final int closingBalance;
  final int totalCredits;
  final int totalDebits;
  final List<ExtractedLine> lines;
}

/// One line of an [ExtractedStatement].
class ExtractedLine {
  const ExtractedLine({
    required this.date,
    required this.amount,
    required this.rawText,
    required this.label,
    this.balance,
  });

  /// Booking date.
  final CalendarDate date;

  /// Signed, in cents: positive when money comes in.
  final int amount;

  /// The bank's text, its lines separated by `\n`: immutable, read by the
  /// rules.
  final String rawText;

  /// The short label: the initial description.
  final String label;

  /// The balance the statement prints after this line, if any.
  final int? balance;
}

/// The outcome of `Ledger.importStatement`: the modification to write, and
/// what to tell the user.
class StatementImport {
  const StatementImport({required this.modification, required this.statementId, required this.first});

  final Modification modification;
  final String statementId;

  /// The first statement of the account: it sets the starting balance, and
  /// no earlier statement can be imported afterwards. The app asks for
  /// confirmation before writing it.
  final bool first;
}
