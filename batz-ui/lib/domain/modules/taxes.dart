/// Taxes by fiscal year (specification, 4.7; decision H4 of phase 6): five
/// lines whose amounts the app computes from what the user enters, their
/// total and its share of the salary, and a control against what the
/// economic view of the year counts in the taxes category.
library;

import 'package:equatable/equatable.dart';

import '../ids.dart';
import '../journal/journal_entry.dart';
import '../ledger/ledger.dart';
import '../ledger/ledger_exception.dart';
import '../views/year_view.dart';
import 'salary.dart';
import 'settings.dart';

/// The five lines of a fiscal year.
enum TaxKind {
  federalIncome,
  cantonalIncome,
  communalIncome,
  cantonalWealth,
  communalWealth;

  /// The lines of wealth take the taxable wealth of the year as base.
  bool get onWealth => this == cantonalWealth || this == communalWealth;
}

/// Journal entity and fields of a fiscal year (« TaxYear »).
abstract final class TaxYearFields {
  static const entity = 'taxYear';
  static const year = 'year';

  /// In cents: the base of both lines of wealth, entered once.
  static const taxableWealth = 'taxableWealth';

  /// The marginal rate (« TMI »), in hundredths of a percent.
  static const marginalRate = 'marginalRate';
}

/// Journal entity and fields of a line of a fiscal year (« TaxLine »).
abstract final class TaxLineFields {
  static const entity = 'taxLine';
  static const year = 'year';
  static const tax = 'tax';

  /// In cents, for the lines of income.
  static const base = 'base';

  /// In ten-thousandths of a percent: 25000 is 2.5000 %.
  static const baseRate = 'baseRate';

  /// In hundredths of a percent: 15500 is 155.00 %.
  static const coefficient = 'coefficient';
}

/// 100 % in ten-thousandths of a percent, the bound of a base rate.
const fullBaseRate = 1000000;

/// 100 % in hundredths of a percent: the default coefficient, and the
/// bound of the marginal rate.
const fullCoefficient = 10000;

/// Identifiers computed from the year, and from the year and the tax
/// (principle 5): two devices entering the same year write the same
/// records.
String taxYearId(int year) => derivedId('tax-year/$year');
String taxLineId(int year, TaxKind tax) => derivedId('tax-line/$year/${tax.name}');

class TaxYear extends Equatable {
  const TaxYear({required this.id, required this.year, this.taxableWealth, this.marginalRate});

  final String id;
  final int year;
  final int? taxableWealth;
  final int? marginalRate;

  @override
  List<Object?> get props => [id, year, taxableWealth, marginalRate];
}

class TaxLine extends Equatable {
  const TaxLine({required this.id, required this.year, required this.tax, this.base, this.baseRate, this.coefficient});

  final String id;
  final int year;
  final TaxKind tax;
  final int? base;
  final int? baseRate;
  final int? coefficient;

  @override
  List<Object?> get props => [id, year, tax, base, baseRate, coefficient];
}

/// [cents] × [baseRate] × [coefficient], rounded once to the cent, halves
/// away from zero (principle 6).
int taxAmount(int cents, int baseRate, int coefficient) {
  final product = BigInt.from(cents) * BigInt.from(baseRate) * BigInt.from(coefficient);
  return _round(product, BigInt.from(fullBaseRate) * BigInt.from(fullCoefficient));
}

/// The total rate of a line, base rate × coefficient, in ten-thousandths of
/// a percent, rounded to the fourth decimal.
int totalRate(int baseRate, int coefficient) =>
    _round(BigInt.from(baseRate) * BigInt.from(coefficient), BigInt.from(fullCoefficient));

/// [part] over [whole], in hundredths of a percent, rounded.
int shareOf(int part, int whole) => _round(BigInt.from(part) * BigInt.from(10000), BigInt.from(whole));

int _round(BigInt numerator, BigInt denominator) {
  final negative = numerator.isNegative != denominator.isNegative && numerator != BigInt.zero;
  final n = numerator.abs(), d = denominator.abs();
  final rounded = (n * BigInt.two + d) ~/ (d * BigInt.two);
  return (negative ? -rounded : rounded).toInt();
}

/// What the user enters for one line.
class TaxLineDraft {
  const TaxLineDraft({this.base, this.baseRate, this.coefficient = fullCoefficient});

  final int? base;
  final int? baseRate;
  final int coefficient;
}

/// What the user enters for a fiscal year.
class TaxYearDraft {
  const TaxYearDraft({required this.year, this.taxableWealth, this.marginalRate, this.lines = const {}});

  final int year;
  final int? taxableWealth;
  final int? marginalRate;
  final Map<TaxKind, TaxLineDraft> lines;
}

/// One line of a fiscal year, computed.
class TaxLineResult {
  const TaxLineResult({
    required this.tax,
    required this.base,
    required this.baseRate,
    required this.coefficient,
    required this.totalRate,
    required this.amount,
  });

  final TaxKind tax;

  /// For a line of wealth, the taxable wealth of the year.
  final int? base;
  final int? baseRate;
  final int coefficient;

  /// Null while the line is incomplete.
  final int? totalRate;

  /// 0 while the line is incomplete.
  final int amount;
}

/// A fiscal year, computed when its screen opens (principle 8).
class TaxYearResult {
  const TaxYearResult({
    required this.year,
    required this.record,
    required this.lines,
    required this.sheet,
    required this.paid,
    required this.categoryFound,
  });

  final int year;
  final TaxYear? record;
  final List<TaxLineResult> lines;
  final SalarySheet? sheet;

  /// What the economic view of the year counts in the taxes category,
  /// refunds deducted; null when the year has no tree or the tree no such
  /// category: then there is no control.
  final int? paid;
  final bool categoryFound;

  /// The sum of the five amounts.
  int get total => lines.fold(0, (sum, l) => sum + l.amount);

  /// Of the gross and of the net of the salary sheet of the year, in
  /// hundredths of a percent; null without sheet.
  int? get shareOfGross => sheet == null || sheet!.gross == 0 ? null : shareOf(total, sheet!.gross);
  int? get shareOfNet => sheet == null || sheet!.net == 0 ? null : shareOf(total, sheet!.net);

  /// Total minus paid: left to pay when positive, paid too much when
  /// negative.
  int? get gap => paid == null ? null : total - paid!;
}

/// The fiscal years and their operations.
extension TaxOperations on Ledger {
  /// The years that have a fiscal year entered, in increasing order.
  List<int> get taxYears => modules.taxYears.keys.toList()..sort();

  /// The fiscal year [year], computed: the record and its lines, the
  /// salary sheet of the year, and the control.
  TaxYearResult taxYear(int year) {
    final record = modules.taxYears[year];
    final lines = modules.taxLines[year] ?? const {};
    final category = moduleCategory(ModuleKind.taxes, year);
    final paid = category == null
        ? null
        : -views.linesIn(year, ViewKind.economic, category.id).fold(0, (sum, l) => sum + l.total);
    return TaxYearResult(
      year: year,
      record: record,
      lines: [
        for (final tax in TaxKind.values)
          () {
            final line = lines[tax];
            final base = tax.onWealth ? record?.taxableWealth : line?.base;
            final rate = line?.baseRate;
            final coefficient = line?.coefficient ?? fullCoefficient;
            final complete = base != null && rate != null;
            return TaxLineResult(
              tax: tax,
              base: base,
              baseRate: rate,
              coefficient: coefficient,
              totalRate: rate == null ? null : totalRate(rate, coefficient),
              amount: complete ? taxAmount(base, rate, coefficient) : 0,
            );
          }(),
      ],
      sheet: salarySheet(year),
      paid: paid,
      categoryFound: category != null,
    );
  }

  /// Creates or modifies the fiscal year [TaxYearDraft.year] and its five
  /// lines. Refused, with its reason: a negative base or taxable wealth, a
  /// base rate out of 0 to 100 %, a negative coefficient, a marginal rate
  /// out of 0 to 100 %.
  Modification saveTaxYear(TaxYearDraft draft) {
    final wealth = draft.taxableWealth, marginal = draft.marginalRate;
    if (wealth != null && wealth < 0) throw const LedgerException(LedgerError.taxBaseNegative);
    if (marginal != null && (marginal < 0 || marginal > fullCoefficient)) {
      throw const LedgerException(LedgerError.taxMarginalRateInvalid);
    }
    for (final line in draft.lines.values) {
      if (line.base != null && line.base! < 0) throw const LedgerException(LedgerError.taxBaseNegative);
      if (line.baseRate != null && (line.baseRate! < 0 || line.baseRate! > fullBaseRate)) {
        throw const LedgerException(LedgerError.taxRateInvalid);
      }
      if (line.coefficient < 0) throw const LedgerException(LedgerError.taxCoefficientNegative);
    }
    final year = draft.year;
    return Modification([
      for (final field in {
        TaxYearFields.year: year,
        TaxYearFields.taxableWealth: wealth,
        TaxYearFields.marginalRate: marginal,
        deletedField: false,
      }.entries)
        FieldChange(TaxYearFields.entity, taxYearId(year), field.key, field.value),
      for (final tax in TaxKind.values)
        for (final field in {
          TaxLineFields.year: year,
          TaxLineFields.tax: tax.name,
          TaxLineFields.base: tax.onWealth ? null : draft.lines[tax]?.base,
          TaxLineFields.baseRate: draft.lines[tax]?.baseRate,
          TaxLineFields.coefficient: draft.lines[tax]?.coefficient ?? fullCoefficient,
          deletedField: false,
        }.entries)
          FieldChange(TaxLineFields.entity, taxLineId(year, tax), field.key, field.value),
    ]);
  }

  /// Deletes the fiscal year [year] and its lines.
  Modification deleteTaxYear(int year) {
    if (!modules.taxYears.containsKey(year)) throw const LedgerException(LedgerError.unknownTaxYear);
    return Modification([
      FieldChange(TaxYearFields.entity, taxYearId(year), deletedField, true),
      for (final line in (modules.taxLines[year] ?? const <TaxKind, TaxLine>{}).values)
        FieldChange(TaxLineFields.entity, line.id, deletedField, true),
    ]);
  }
}
