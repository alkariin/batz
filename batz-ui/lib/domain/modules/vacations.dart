/// The trips: the lines of the vacation category, every year together,
/// grouped into trips by their periods; what the user enters about a trip
/// is kept on a sheet attached to its first line, or on a manual line.
library;

import 'package:equatable/equatable.dart';

import '../calendar_date.dart';
import '../ids.dart';
import '../journal/journal_entry.dart';
import '../ledger/ledger.dart';
import '../ledger/ledger_exception.dart';
import '../views/year_view.dart';
import 'settings.dart';

/// Journal entity and fields of the sheet of a trip (« Trip »).
abstract final class TripSheetFields {
  static const entity = 'tripSheet';

  /// The line the sheet is attached to; absent for a manual line.
  static const lineId = 'lineId';
  static const place = 'place';
  static const days = 'days';

  /// The date and the amount (in cents, a cost is positive) that replace
  /// the automatic ones; required on a manual line.
  static const date = 'date';
  static const amount = 'amount';
}

/// The largest gap, in days, between two lines of one trip.
const tripGapDays = 15;

/// Identifier of the sheet attached to [lineId]: computed.
String tripSheetId(String lineId) => derivedId('trip-sheet/$lineId');

class TripSheet extends Equatable {
  const TripSheet({required this.id, this.lineId, this.place = '', this.days, this.date, this.amount});

  final String id;
  final String? lineId;
  final String place;
  final int? days;
  final CalendarDate? date;
  final int? amount;

  bool get isManual => lineId == null;

  @override
  List<Object?> get props => [id, lineId, place, days, date, amount];
}

/// The number of days from the end of [a]'s period to the start of [b]'s;
/// 0 when they touch or overlap.
int gapDays(ViewLine a, ViewLine b) {
  final days = b.start.toDateTime().difference(a.end.toDateTime()).inDays;
  return days < 0 ? 0 : days;
}

/// [cents] over [days], rounded to the cent, halves away from zero.
int perDay(int cents, int days) {
  final rounded = (cents.abs() * 2 + days) ~/ (2 * days);
  return cents < 0 ? -rounded : rounded;
}

/// A trip: its lines, or a manual line, and what its sheet says.
class Trip {
  Trip._({required this.lines, required this.sheet, required this.extraSheets});

  /// The lines of the category in the trip, oldest period first; empty for
  /// a manual line.
  final List<ViewLine> lines;

  /// The sheet that applies: the one of the oldest line among those that
  /// have one, or the manual line.
  final TripSheet? sheet;

  /// Other sheets attached to lines of the trip: signalled, to delete.
  final List<TripSheet> extraSheets;

  bool get isManual => lines.isEmpty;

  /// The line a new sheet is attached to: the first of the trip.
  String? get anchorLineId => lines.isEmpty ? null : lines.first.ownLineId;

  /// The first day of the oldest period.
  CalendarDate? get automaticDate => lines.isEmpty ? null : lines.first.start;

  /// The opposite of the sum of the lines, refunds deducted.
  int? get automaticAmount => lines.isEmpty ? null : -lines.fold(0, (sum, l) => sum + l.amount);

  CalendarDate get date => sheet?.date ?? automaticDate!;
  int get amount => sheet?.amount ?? automaticAmount!;
  int get year => date.year;
  String get place => sheet?.place ?? '';
  int? get days => sheet?.days;

  bool get dateReplaced => !isManual && sheet?.date != null;
  bool get amountReplaced => !isManual && sheet?.amount != null;

  /// The amount over the days, to the cent; none without days.
  int? get pricePerDay => days == null || days! < 1 ? null : perDay(amount, days!);

  /// Stable within a ledger, for the screens.
  String get key => sheet?.isManual ?? false ? 'manual-${sheet!.id}' : 'line-$anchorLineId';
}

/// The trips of a ledger, computed when the screen asks for them.
class Vacations {
  Vacations._(this.trips, this.orphanSheets, this.lines);

  /// Every trip, the most recent first.
  final List<Trip> trips;

  /// Sheets whose line is in no trip: it left the category, or is gone.
  final List<TripSheet> orphanSheets;

  /// The lines of the category, every year.
  final List<ViewLine> lines;

  /// The years that have trips, the most recent first.
  List<int> get years => {for (final t in trips) t.year}.toList()..sort((a, b) => b.compareTo(a));

  List<Trip> tripsOf(int year) => [
    for (final t in trips)
      if (t.year == year) t,
  ];

  /// The sum of the amounts of the trips of [year].
  int totalOf(int year) => tripsOf(year).fold(0, (sum, t) => sum + t.amount);
}

final _vacations = Expando<Vacations>('vacations');

/// The trips and their operations.
extension VacationOperations on Ledger {
  /// The trips, computed once per ledger when first asked for.
  Vacations get vacations => _vacations[this] ??= _buildVacations();

  Vacations _buildVacations() {
    final lines = [...views.linesNamed(moduleCategoryName(ModuleKind.vacations))]
      ..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        if (byStart != 0) return byStart;
        final byPayment = a.paid.compareTo(b.paid);
        return byPayment != 0 ? byPayment : a.ownLineId.compareTo(b.ownLineId);
      });
    // Lines joined one to the next by gaps of 15 days or less: sorted by
    // start, a line joins the trip while it starts at most 15 days after
    // the latest end so far.
    final groups = <List<ViewLine>>[];
    CalendarDate? end;
    for (final line in lines) {
      if (end == null || line.start.toDateTime().difference(end.toDateTime()).inDays > tripGapDays) {
        groups.add([]);
        end = line.end;
      } else if (line.end.isAfter(end)) {
        end = line.end;
      }
      groups.last.add(line);
    }
    final byLine = <String, TripSheet>{};
    final manual = <TripSheet>[];
    for (final sheet in modules.tripSheets.values) {
      if (sheet.lineId == null) {
        manual.add(sheet);
      } else {
        byLine[sheet.lineId!] = sheet;
      }
    }
    final used = <String>{};
    final trips = <Trip>[
      for (final group in groups)
        () {
          final sheets = [for (final line in group) ?byLine[line.ownLineId]];
          used.addAll(sheets.map((s) => s.id));
          return Trip._(lines: group, sheet: sheets.firstOrNull, extraSheets: sheets.skip(1).toList());
        }(),
      // A manual line is a trip by itself; it needs its date and amount.
      for (final sheet in manual)
        if (sheet.date != null && sheet.amount != null) Trip._(lines: const [], sheet: sheet, extraSheets: const []),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final orphans = [
      for (final sheet in byLine.values)
        if (!used.contains(sheet.id)) sheet,
    ]..sort((a, b) => a.id.compareTo(b.id));
    return Vacations._(trips, orphans, lines);
  }

  /// Enters what the user knows of [trip]: the place, the days, and the
  /// date and amount that replace the automatic ones (null restores them).
  /// The sheet that applies is modified; without one, a sheet is attached to
  /// the first line of the trip. Refused when the days are below 1.
  Modification saveTrip(Trip trip, {required String place, int? days, CalendarDate? date, int? amount}) {
    if (days != null && days < 1) throw const LedgerException(LedgerError.tripDaysInvalid);
    if (trip.isManual) {
      return saveManualTrip(trip.sheet!.id, place: place, days: days, date: date, amount: amount);
    }
    final id = trip.sheet?.id ?? tripSheetId(trip.anchorLineId!);
    return Modification.set(TripSheetFields.entity, id, {
      TripSheetFields.lineId: trip.sheet?.lineId ?? trip.anchorLineId,
      TripSheetFields.place: place.trim(),
      TripSheetFields.days: days,
      TripSheetFields.date: date?.encode(),
      TripSheetFields.amount: amount,
      deletedField: false,
    });
  }

  /// Creates or modifies the manual line [id]: a trip by itself. Refused
  /// without a date or an amount, or with days below 1.
  Modification saveManualTrip(String id, {required String place, int? days, CalendarDate? date, int? amount}) {
    if (date == null) throw const LedgerException(LedgerError.tripDateRequired);
    if (amount == null) throw const LedgerException(LedgerError.tripAmountRequired);
    if (days != null && days < 1) throw const LedgerException(LedgerError.tripDaysInvalid);
    return Modification.set(TripSheetFields.entity, id, {
      TripSheetFields.lineId: null,
      TripSheetFields.place: place.trim(),
      TripSheetFields.days: days,
      TripSheetFields.date: date.encode(),
      TripSheetFields.amount: amount,
    });
  }

  /// Deletes the sheet [id]: a manual line, a sheet in excess or without
  /// line.
  Modification deleteTripSheet(String id) {
    if (!modules.tripSheets.containsKey(id)) throw const LedgerException(LedgerError.unknownTripSheet);
    return Modification.delete(TripSheetFields.entity, id);
  }
}

/// Identifier of a new manual line: random.
String newManualTripId() => newId();
