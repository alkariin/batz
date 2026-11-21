/// The annual salary sheet: gross, a free list of deductions, net, and the
/// gap when gross minus the deductions does not give the net. It has no
/// effect on the accounts.
library;

import 'package:equatable/equatable.dart';

import '../ids.dart' show derivedId;
import '../journal/journal_entry.dart';
import '../ledger/ledger.dart';
import '../ledger/ledger_exception.dart';

/// Journal entity and fields of a salary sheet (« SalarySheet »).
abstract final class SalarySheetFields {
  static const entity = 'salarySheet';
  static const year = 'year';

  /// In cents.
  static const gross = 'gross';
  static const net = 'net';
}

/// Journal entity and fields of a deduction of a salary sheet
/// (« SalaryDeduction »).
abstract final class SalaryDeductionFields {
  static const entity = 'salaryDeduction';
  static const sheetId = 'sheetId';
  static const label = 'label';

  /// In cents.
  static const amount = 'amount';

  /// Its place in the sheet, from 0.
  static const rank = 'rank';
}

/// The labels proposed for the first sheet.
const defaultDeductionLabels = ['AVS', 'AC', 'LPP'];

/// Identifier of the sheet of [year]: computed, one sheet per year even
/// when two devices create it.
String salarySheetId(int year) => derivedId('salary-sheet/$year');

class SalaryDeduction extends Equatable {
  const SalaryDeduction({
    required this.id,
    required this.sheetId,
    required this.label,
    required this.amount,
    required this.rank,
  });

  final String id;
  final String sheetId;
  final String label;
  final int amount;
  final int rank;

  @override
  List<Object?> get props => [id, sheetId, label, amount, rank];
}

/// The salary sheet of one year, its deductions by rank.
class SalarySheet extends Equatable {
  SalarySheet({
    required this.id,
    required this.year,
    required this.gross,
    required this.net,
    Iterable<SalaryDeduction> deductions = const [],
  }) : deductions = List<SalaryDeduction>.unmodifiable(
         <SalaryDeduction>[...deductions]
           ..sort((a, b) => a.rank != b.rank ? a.rank.compareTo(b.rank) : a.id.compareTo(b.id)),
       );

  final String id;
  final int year;
  final int gross;
  final int net;
  final List<SalaryDeduction> deductions;

  int get deductionsTotal => deductions.fold(0, (sum, d) => sum + d.amount);

  /// Gross minus the deductions minus net: shown when it is not zero, it
  /// never prevents saving.
  int get gap => gross - deductionsTotal - net;

  SalarySheet withDeductions(Iterable<SalaryDeduction> deductions) =>
      SalarySheet(id: id, year: year, gross: gross, net: net, deductions: deductions);

  @override
  List<Object?> get props => [id, year, gross, net, deductions];
}

/// A deduction as the form gives it: [id] is null for a new one.
class DeductionDraft {
  const DeductionDraft({this.id, required this.label, required this.amount});

  final String? id;
  final String label;
  final int amount;
}

/// What the user enters for the sheet of a year.
class SalarySheetDraft {
  const SalarySheetDraft({required this.year, required this.gross, required this.net, this.deductions = const []});

  final int year;
  final int gross;
  final int net;
  final List<DeductionDraft> deductions;
}

/// The salary sheets and their operations.
extension SalaryOperations on Ledger {
  /// The sheet of [year], if there is one.
  SalarySheet? salarySheet(int year) => modules.salarySheets[year];

  /// The labels a new sheet of [year] proposes: those of the sheet of the
  /// closest earlier year that has one, otherwise AVS, AC and LPP.
  List<String> proposedDeductionLabels(int year) {
    SalarySheet? previous;
    for (final sheet in modules.salarySheets.values) {
      if (sheet.year < year && (previous == null || sheet.year > previous.year)) previous = sheet;
    }
    final labels = [for (final d in previous?.deductions ?? const <SalaryDeduction>[]) d.label];
    return labels.isEmpty ? defaultDeductionLabels : labels;
  }

  /// Creates or modifies the sheet of [SalarySheetDraft.year] with its
  /// deductions, in their order: those of the draft without identifier are
  /// added ([newId] gives theirs), those of the sheet no longer in the draft
  /// are removed. Refused, with its reason: a gross of zero or less, a net
  /// below zero, a deduction without label or below zero.
  Modification saveSalarySheet(SalarySheetDraft draft, {required String Function() newId}) {
    if (draft.gross <= 0) throw const LedgerException(LedgerError.salaryGrossRequired);
    if (draft.net < 0) throw const LedgerException(LedgerError.salaryNetNegative);
    for (final d in draft.deductions) {
      if (d.label.trim().isEmpty) throw const LedgerException(LedgerError.salaryDeductionLabelRequired);
      if (d.amount < 0) throw const LedgerException(LedgerError.salaryDeductionNegative);
    }
    final id = salarySheetId(draft.year);
    final existing = salarySheet(draft.year);
    final kept = {for (final d in draft.deductions) ?d.id};
    final ids = [for (final d in draft.deductions) d.id ?? newId()];
    return Modification([
      for (final field in {
        SalarySheetFields.year: draft.year,
        SalarySheetFields.gross: draft.gross,
        SalarySheetFields.net: draft.net,
        // A sheet deleted that year comes back.
        deletedField: false,
      }.entries)
        FieldChange(SalarySheetFields.entity, id, field.key, field.value),
      for (final (rank, d) in draft.deductions.indexed) ...[
        for (final field in {
          SalaryDeductionFields.sheetId: id,
          SalaryDeductionFields.label: d.label.trim(),
          SalaryDeductionFields.amount: d.amount,
          SalaryDeductionFields.rank: rank,
        }.entries)
          FieldChange(SalaryDeductionFields.entity, ids[rank], field.key, field.value),
      ],
      for (final d in existing?.deductions ?? const <SalaryDeduction>[])
        if (!kept.contains(d.id)) FieldChange(SalaryDeductionFields.entity, d.id, deletedField, true),
    ]);
  }

  /// Deletes the sheet of [year] and its deductions.
  Modification deleteSalarySheet(int year) {
    final sheet = salarySheet(year);
    if (sheet == null) throw const LedgerException(LedgerError.unknownSalarySheet);
    return Modification([
      FieldChange(SalarySheetFields.entity, sheet.id, deletedField, true),
      for (final d in sheet.deductions) FieldChange(SalaryDeductionFields.entity, d.id, deletedField, true),
    ]);
  }
}
