/// Electricity: the kWh entered for the lines of the electricity category,
/// and per year the price of the economic view, the kWh spread like the
/// amounts, the days covered and three ratios.
library;

import 'package:equatable/equatable.dart';

import '../allocation.dart';
import '../calendar_date.dart';
import '../ids.dart';
import '../journal/journal_entry.dart';
import '../ledger/ledger.dart';
import '../ledger/ledger_exception.dart';
import '../views/year_view.dart';
import 'settings.dart';

/// Journal entity and fields of the energy of a line (« ElectricityReading »).
abstract final class ElectricityReadingFields {
  static const entity = 'electricityReading';
  static const lineId = 'lineId';

  /// In Wh, an integer.
  static const wh = 'wh';
}

/// Identifier of the reading of [lineId]: computed, so that two devices
/// entering the kWh of the same line write one record.
String electricityReadingId(String lineId) => derivedId('electricity/$lineId');

class ElectricityReading extends Equatable {
  const ElectricityReading({required this.id, required this.lineId, required this.wh});

  final String id;
  final String lineId;
  final int wh;

  @override
  List<Object?> get props => [id, lineId, wh];
}

/// One line that counts in a year, with its kWh.
class ElectricityLine {
  const ElectricityLine({required this.line, required this.amount, required this.reading, required this.whInYear});

  final ViewLine line;

  /// What the line places in the category in the year, a cost positive.
  final int amount;
  final ElectricityReading? reading;

  /// The part of its energy that falls in the year, spread like its amount.
  final int? whInYear;

  /// The days of its period.
  int get days => line.end.toDateTime().difference(line.start.toDateTime()).inDays + 1;
}

/// The electricity of one year.
class ElectricityYear {
  const ElectricityYear({
    required this.year,
    required this.categoryFound,
    required this.lines,
    required this.price,
    required this.wh,
    required this.days,
  });

  final int year;
  final bool categoryFound;
  final List<ElectricityLine> lines;

  /// The total of the category in the economic view of the year, a cost
  /// positive, before redistribution.
  final int price;

  /// The energy spread into the year, in Wh.
  final int wh;

  /// The days of the year covered by the period of at least one line.
  final int days;

  /// The lines without kWh: while there are, the price per kWh is
  /// overestimated.
  int get linesWithoutKwh => lines.where((l) => l.reading == null).length;

  /// Price per day in cents; per kWh in ten-thousandths of a franc; kWh per
  /// day in hundredths. Null when the divisor is zero.
  int? get pricePerDay => days == 0 ? null : _round(price, days);
  int? get pricePerKwh => wh == 0 ? null : _round(price * 100000, wh);
  int? get kwhPerDay => days == 0 ? null : _round(wh, days * 10);
}

int _round(int numerator, int denominator) {
  final rounded = (numerator.abs() * 2 + denominator) ~/ (2 * denominator);
  return numerator < 0 ? -rounded : rounded;
}

/// The electricity and its operations.
extension ElectricityOperations on Ledger {
  /// The electricity of [year], computed when the screen asks for it.
  ElectricityYear electricityYear(int year) {
    final category = moduleCategory(ModuleKind.electricity, year);
    if (category == null) {
      return ElectricityYear(year: year, categoryFound: false, lines: const [], price: 0, wh: 0, days: 0);
    }
    final first = CalendarDate(year, 1, 1), last = CalendarDate(year, 12, 31);
    final covered = <int>{};
    final lines = <ElectricityLine>[];
    for (final counted in views.linesIn(year, ViewKind.economic, category.id)) {
      final line = counted.line;
      final reading = modules.electricityReadings[line.ownLineId];
      final wh = reading == null
          ? null
          : allocate(
              reading.wh,
              line.start,
              line.end,
            ).where((share) => share.month.year == year).fold(0, (sum, share) => sum + share.cents);
      lines.add(ElectricityLine(line: line, amount: -counted.total, reading: reading, whInYear: wh));
      final from = line.start.isBefore(first) ? first : line.start;
      final to = line.end.isAfter(last) ? last : line.end;
      for (var day = from; !day.isAfter(to); day = day.addDays(1)) {
        covered.add(day.toDateTime().millisecondsSinceEpoch);
      }
    }
    return ElectricityYear(
      year: year,
      categoryFound: true,
      lines: lines,
      price: lines.fold(0, (sum, l) => sum + l.amount),
      wh: lines.fold(0, (sum, l) => sum + (l.whInYear ?? 0)),
      days: covered.length,
    );
  }

  /// The years shown: those where lines count in the category.
  List<int> electricityYears({required int currentYear}) => [
    for (final year in views.years(currentYear: currentYear))
      if (electricityYear(year).lines.isNotEmpty) year,
  ];

  /// Readings whose line no longer counts in the category.
  List<ElectricityReading> get orphanReadings {
    final lines = {for (final l in views.linesNamed(moduleCategoryName(ModuleKind.electricity))) l.ownLineId};
    return [
      for (final r in modules.electricityReadings.values)
        if (!lines.contains(r.lineId)) r,
    ]..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Enters the energy of [lineId] in Wh; null erases it. Refused when
  /// negative.
  Modification setElectricity(String lineId, int? wh) {
    final id = electricityReadingId(lineId);
    if (wh == null) {
      if (!modules.electricityReadings.containsKey(lineId)) {
        throw const LedgerException(LedgerError.unknownElectricityReading);
      }
      return Modification.delete(ElectricityReadingFields.entity, id);
    }
    if (wh < 0) throw const LedgerException(LedgerError.electricityNegative);
    return Modification.set(ElectricityReadingFields.entity, id, {
      ElectricityReadingFields.lineId: lineId,
      ElectricityReadingFields.wh: wh,
      deletedField: false,
    });
  }
}
