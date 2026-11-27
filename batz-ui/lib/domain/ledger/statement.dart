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

  /// SHA-256 of the file: the server keeps the file under it.
  static const fingerprint = 'fingerprint';
}

/// A statement imported into a detailed account. Its lines are the
/// transactions whose `statementId` is its identifier.
///
/// The import of an export without balances (Neon) is one too: its lines
/// are those the export brought that no earlier export had; its period runs
/// from the day after the previous import (from its first line for the
/// first one) to the day of the import; its closing balance is the one the
/// user typed, its opening one the closing balance of the previous import
/// (for the first one, the balance typed less the lines).
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

/// Identifier of a line of an export without balances: computed from the
/// account, the date, the amount and the raw text of the line, and its rank
/// among the identical lines of the file ([occurrence], from 0), so that an
/// export that overlaps an earlier one brings only its new lines.
String exportedTransactionId(String accountId, CalendarDate date, int amount, String rawText, int occurrence) =>
    derivedId('export-line/$accountId/${date.encode()}/$amount/$occurrence/$rawText');

/// What the server read in a statement file (`POST /api/v1/imports`). An
/// export without balances (Neon) has neither balances nor totals.
class ExtractedStatement {
  const ExtractedStatement({
    required this.format,
    required this.iban,
    required this.currency,
    required this.periodStart,
    required this.periodEnd,
    this.openingBalance,
    this.closingBalance,
    this.totalCredits,
    this.totalDebits,
    required this.lines,
  });

  final String format;
  final String iban;
  final String currency;
  final CalendarDate periodStart;
  final CalendarDate periodEnd;
  final int? openingBalance;
  final int? closingBalance;
  final int? totalCredits;
  final int? totalDebits;
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

/// What an export without balances would bring, before the user types the
/// balance (`Ledger.previewImport`).
class ImportPreview {
  const ImportPreview({required this.newLines, required this.first, this.previousClosing});

  /// The lines no earlier import of the account holds.
  final int newLines;

  /// The first import of the account: the balance typed sets its starting
  /// balance.
  final bool first;

  /// The balance of the latest import, before the new lines.
  final int? previousClosing;
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
