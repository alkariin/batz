import 'dart:math';

import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/vacations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/module_checks.dart';

Matcher throwsLedger(LedgerError error) => throwsA(isA<LedgerException>().having((e) => e.error, 'error', error));

/// « Vacances » under the expenses of 2026, and the example of the plan: a
/// flight of 640.00 paid on 12.3 for 10.7 – 24.7 (or for its payment day
/// only, without [flightPeriod]); a hotel of 1'200.00 on 11.7; a restaurant
/// of 85.00 on 20.7; 100.00 refunded on 5.8, attached to the hotel; 300.00 on
/// 9.8.
Future<Ledger> vacationExample(LedgerHarness h, {bool flightPeriod = true}) async {
  await h.apply(
    (l) => l.addCategory('trips', year: 2026, name: 'Vacances', parentId: defaultGroupId(2026, CategoryNature.expense)),
  );
  await h.apply(
    (l) => l.recordEntry(
      'flight',
      'flight-line',
      entry(
        category: 'trips',
        cents: 64000,
        date: d(2026, 3, 12),
        periodStart: flightPeriod ? d(2026, 7, 10) : null,
        periodEnd: flightPeriod ? d(2026, 7, 24) : null,
      ),
    ),
  );
  await h.apply(
    (l) => l.recordEntry('hotel', 'hotel-line', entry(category: 'trips', cents: 120000, date: d(2026, 7, 11))),
  );
  await h.apply((l) => l.recordEntry('meal', 'meal-line', entry(category: 'trips', cents: 8500, date: d(2026, 7, 20))));
  await h.apply(
    (l) => l.recordEntry(
      'back',
      'back-line',
      EntryDraft(
        accountId: 'cash',
        date: d(2026, 8, 5),
        cents: 10000,
        direction: Direction.inflow,
        categoryId: null,
        refundedLineId: 'hotel-line',
      ),
    ),
  );
  return h.apply(
    (l) => l.recordEntry('later', 'later-line', entry(category: 'trips', cents: 30000, date: d(2026, 8, 9))),
  );
}

/// Each trip as (date, amount, its lines).
List<(CalendarDate, int, String)> trips(Ledger ledger) => [
  for (final t in ledger.vacations.trips) (t.date, t.amount, [for (final l in t.lines) l.ownLineId].join(' ')),
];

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
  });
  tearDown(() => h.close());

  test('the example: two trips, the first on 10.7.2026 for 1\'825.00, 130.36 a day over 14 days; the second on '
      '9.8.2026, 16 days after it, for 300.00', () async {
    var ledger = await vacationExample(h);
    expect(trips(ledger), [
      (d(2026, 8, 9), 30000, 'later-line'),
      (d(2026, 7, 10), 182500, 'flight-line hotel-line back-line meal-line'),
    ]);
    final first = ledger.vacations.trips.last;
    expect(
      first.lines.firstWhere((l) => l.ownLineId == 'back-line').start,
      d(2026, 7, 11),
      reason: 'the refund follows its expense',
    );
    ledger = await h.apply((l) => l.saveTrip(first, place: 'Lisbonne', days: 14));
    final trip = ledger.vacations.trips.last;
    expect((trip.place, trip.days, trip.amount, trip.pricePerDay), ('Lisbonne', 14, 182500, 13036));
    expect(trip.sheet!.id, tripSheetId('flight-line'), reason: 'attached to the first line');
    expect(ledger.vacations.tripsOf(2026), hasLength(2));
    expect(ledger.vacations.totalOf(2026), 212500);
    expect(ledger.vacations.trips.first.pricePerDay, isNull, reason: 'no days');
  });

  test(
    'a flight ticket whose period is the trip\'s joins it; without, it forms a trip of its own on 12.3.2026',
    () async {
      final ledger = await vacationExample(h, flightPeriod: false);
      expect(trips(ledger), [
        (d(2026, 8, 9), 30000, 'later-line'),
        (d(2026, 7, 11), 118500, 'hotel-line back-line meal-line'),
        (d(2026, 3, 12), 64000, 'flight-line'),
      ]);
    },
  );

  test('15 days of gap join, 16 separate', () async {
    await h.apply(
      (l) =>
          l.addCategory('trips', year: 2026, name: 'Vacances', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
    await h.apply(
      (l) => l.recordEntry(
        'a',
        'a-l',
        entry(
          category: 'trips',
          cents: 100,
          date: d(2026, 7, 1),
          periodStart: d(2026, 7, 10),
          periodEnd: d(2026, 7, 24),
        ),
      ),
    );
    var ledger = await h.apply(
      (l) => l.recordEntry('b', 'b-l', entry(category: 'trips', cents: 100, date: d(2026, 8, 8))),
    );
    expect(ledger.vacations.trips, hasLength(1), reason: '24.7 to 8.8: 15 days');
    ledger = await h.apply((l) => l.updateEntry('b', entry(category: 'trips', cents: 100, date: d(2026, 8, 9))));
    expect(ledger.vacations.trips, hasLength(2), reason: '24.7 to 9.8: 16 days');
  });

  test('a transaction between two trips joins them; its period or its category changed, they part again', () async {
    await h.apply(
      (l) =>
          l.addCategory('trips', year: 2026, name: 'Vacances', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
    await h.apply(
      (l) => l.recordEntry(
        'a',
        'a-l',
        entry(category: 'trips', cents: 100, date: d(2026, 7, 1), periodEnd: d(2026, 7, 5), periodStart: d(2026, 7, 1)),
      ),
    );
    var ledger = await h.apply(
      (l) => l.recordEntry('b', 'b-l', entry(category: 'trips', cents: 200, date: d(2026, 7, 25))),
    );
    expect(ledger.vacations.trips, hasLength(2));
    ledger = await h.apply(
      (l) => l.recordEntry('c', 'c-l', entry(category: 'trips', cents: 400, date: d(2026, 7, 15))),
    );
    expect(trips(ledger), [(d(2026, 7, 1), 700, 'a-l c-l b-l')]);
    ledger = await h.apply(
      (l) => l.updateEntry(
        'c',
        entry(
          category: 'trips',
          cents: 400,
          date: d(2026, 7, 15),
          periodStart: d(2026, 9, 1),
          periodEnd: d(2026, 9, 2),
        ),
      ),
    );
    expect(ledger.vacations.trips, hasLength(3), reason: 'its period moved');
    ledger = await h.apply((l) => l.updateEntry('c', entry(category: 'trips', cents: 400, date: d(2026, 7, 15))));
    expect(ledger.vacations.trips, hasLength(1));
    ledger = await h.apply((l) => l.updateEntry('c', entry(category: 'food', cents: 400, date: d(2026, 7, 15))));
    expect(ledger.vacations.trips, hasLength(2), reason: 'it left the category');
  });

  test('a date and an amount replaced stay when the trip changes, the automatic values beside; restored, they '
      'follow again', () async {
    await h.apply(
      (l) =>
          l.addCategory('trips', year: 2026, name: 'Vacances', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
    var ledger = await h.apply(
      (l) => l.recordEntry('a', 'a-l', entry(category: 'trips', cents: 40000, date: d(2026, 7, 1))),
    );
    ledger = await h.apply(
      (l) => l.saveTrip(l.vacations.trips.single, place: 'Rome', days: 5, date: d(2026, 6, 30), amount: 50000),
    );
    ledger = await h.apply(
      (l) => l.recordEntry('b', 'b-l', entry(category: 'trips', cents: 20000, date: d(2026, 7, 3))),
    );
    var trip = ledger.vacations.trips.single;
    expect(
      (trip.date, trip.amount, trip.automaticDate, trip.automaticAmount),
      (d(2026, 6, 30), 50000, d(2026, 7, 1), 60000),
    );
    expect((trip.dateReplaced, trip.amountReplaced, trip.pricePerDay), (true, true, 10000));
    ledger = await h.apply((l) => l.saveTrip(trip, place: 'Rome', days: 5));
    trip = ledger.vacations.trips.single;
    expect((trip.date, trip.amount, trip.dateReplaced, trip.amountReplaced), (d(2026, 7, 1), 60000, false, false));
    expect(() => ledger.saveTrip(trip, place: 'Rome', days: 0), throwsLedger(LedgerError.tripDaysInvalid));
  });

  test('two sheets on one trip: the oldest line\'s applies, the other is signalled and deleted; a sheet whose line '
      'left the category is listed apart', () async {
    await h.apply(
      (l) =>
          l.addCategory('trips', year: 2026, name: 'Vacances', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
    await h.apply((l) => l.recordEntry('a', 'a-l', entry(category: 'trips', cents: 100, date: d(2026, 7, 1))));
    var ledger = await h.apply(
      (l) => l.recordEntry('b', 'b-l', entry(category: 'trips', cents: 100, date: d(2026, 7, 25))),
    );
    for (final (trip, place) in [(ledger.vacations.trips[0], 'Paris'), (ledger.vacations.trips[1], 'Rome')]) {
      ledger = await h.apply((l) => l.saveTrip(trip, place: place));
    }
    ledger = await h.apply(
      (l) => l.recordEntry('c', 'c-l', entry(category: 'trips', cents: 100, date: d(2026, 7, 13))),
    );
    var trip = ledger.vacations.trips.single;
    expect(trip.place, 'Rome', reason: 'the sheet of the oldest line');
    expect(trip.extraSheets.map((s) => s.place), ['Paris']);
    ledger = await h.apply((l) => l.deleteTripSheet(trip.extraSheets.single.id));
    expect(ledger.vacations.trips.single.extraSheets, isEmpty);

    ledger = await h.apply((l) => l.updateEntry('a', entry(category: 'food', cents: 100, date: d(2026, 7, 1))));
    trip = ledger.vacations.trips.single;
    expect((trip.place, trip.anchorLineId), ('', 'c-l'));
    expect(ledger.vacations.orphanSheets.map((s) => (s.place, s.lineId)), [('Rome', 'a-l')]);
    ledger = await h.apply((l) => l.deleteTripSheet(ledger.vacations.orphanSheets.single.id));
    expect(ledger.vacations.orphanSheets, isEmpty);
    expect(() => ledger.deleteTripSheet('gone'), throwsLedger(LedgerError.unknownTripSheet));
  });

  test('a manual line is a trip by itself; its date and amount are required, its days at least 1', () async {
    var ledger = await h.ledger();
    expect(() => ledger.saveManualTrip('m', place: 'Camping', amount: 1), throwsLedger(LedgerError.tripDateRequired));
    expect(
      () => ledger.saveManualTrip('m', place: 'Camping', date: d(2025, 8, 1)),
      throwsLedger(LedgerError.tripAmountRequired),
    );
    expect(
      () => ledger.saveManualTrip('m', place: 'Camping', date: d(2025, 8, 1), amount: 1, days: 0),
      throwsLedger(LedgerError.tripDaysInvalid),
    );
    ledger = await h.apply((l) => l.saveManualTrip('m', place: 'Camping', date: d(2025, 8, 1), amount: 45000, days: 6));
    final trip = ledger.vacations.trips.single;
    expect((trip.isManual, trip.year, trip.place, trip.amount, trip.pricePerDay), (true, 2025, 'Camping', 45000, 7500));
    ledger = await h.apply((l) => l.saveTrip(trip, place: 'Camping', date: d(2025, 8, 2), amount: 46000, days: 6));
    expect(ledger.vacations.trips.single.amount, 46000);
    ledger = await h.apply((l) => l.deleteTripSheet('m'));
    expect(ledger.vacations.trips, isEmpty);
  });

  test('on random data, each line of the category is in one trip and one only, lines one gap of 15 days or less '
      'apart share a trip, and the automatic amounts make the sum of the lines', () {
    for (var seed = 1; seed <= 40; seed++) {
      final r = Random(seed);
      final income = defaultGroupId(2026, CategoryNature.income),
          expenses = defaultGroupId(2026, CategoryNature.expense);
      final categories = [
        for (final year in [2026, 2027]) ...[
          Category(id: '$income-$year', year: year, name: 'Revenus', nature: CategoryNature.income, position: 0),
          Category(id: '$expenses-$year', year: year, name: 'Dépenses', nature: CategoryNature.expense, position: 1),
          Category(id: 'trips-$year', year: year, name: 'Vacances', parentId: '$expenses-$year', position: 0),
          Category(id: 'flights-$year', year: year, name: 'Vols', parentId: 'trips-$year', position: 0),
          Category(id: 'food-$year', year: year, name: 'Nourriture', parentId: '$expenses-$year', position: 1),
        ],
      ];
      final transactions = <LedgerTransaction>[], lines = <TransactionLine>[];
      for (var i = 0; i < 60; i++) {
        final year = 2026 + r.nextInt(2);
        final date = CalendarDate(year, 1 + r.nextInt(12), 1 + r.nextInt(28));
        final start = r.nextInt(3) == 0 ? date.addDays(r.nextInt(60)) : date;
        final end = start.addDays(r.nextInt(r.nextInt(4) == 0 ? 40 : 3));
        final amount = (r.nextInt(6) == 0 ? 1 : -1) * (1 + r.nextInt(100000));
        transactions.add(LedgerTransaction(id: 't$i', accountId: 'cash', date: date, amount: amount));
        lines.add(
          TransactionLine(
            id: 't$i-l',
            transactionId: 't$i',
            categoryId: '${['trips', 'flights', 'food'][r.nextInt(3)]}-$year',
            amount: amount,
            periodStart: start,
            periodEnd: end,
          ),
        );
      }
      final ledger = Ledger(
        accounts: const [Account(id: 'cash', name: 'Espèces', type: AccountType.cash)],
        categories: categories,
        transactions: transactions,
        lines: lines,
      );
      final vacations = ledger.vacations;
      final inCategory = vacations.lines;
      expect(inCategory, isNotEmpty);
      final seen = <String>{};
      for (final trip in vacations.trips) {
        for (final line in trip.lines) {
          expect(seen.add(line.ownLineId), isTrue, reason: 'seed $seed: ${line.ownLineId} twice');
        }
        // Inside a trip, sorted by start, each line starts at most 15 days
        // after the latest end before it.
        var end = trip.lines.first.end;
        for (final line in trip.lines.skip(1)) {
          expect(
            line.start.toDateTime().difference(end.toDateTime()).inDays,
            lessThanOrEqualTo(tripGapDays),
            reason: 'seed $seed',
          );
          if (line.end.isAfter(end)) end = line.end;
        }
      }
      expect(seen, {for (final l in inCategory) l.ownLineId}, reason: 'seed $seed: every line, in one trip');
      // Two trips in a row are more than 15 days apart.
      final ordered = [...vacations.trips]..sort((a, b) => a.automaticDate!.compareTo(b.automaticDate!));
      for (var i = 1; i < ordered.length; i++) {
        final previousEnd = ordered[i - 1].lines.map((l) => l.end).reduce((a, b) => a.isAfter(b) ? a : b);
        expect(
          ordered[i].automaticDate!.toDateTime().difference(previousEnd.toDateTime()).inDays,
          greaterThan(tripGapDays),
        );
      }
      expect(
        vacations.trips.fold(0, (s, t) => s + t.automaticAmount!),
        -inCategory.fold(0, (s, l) => s + l.amount),
        reason: 'seed $seed',
      );
    }
  });

  test('the sheets of the trips change neither the annual views nor the wealth', () async {
    final today = d(2026, 11, 21);
    var ledger = await vacationExample(h);
    final before = accountsAndViews(ledger, today);
    ledger = await h.apply((l) => l.saveTrip(l.vacations.trips.last, place: 'Lisbonne', days: 14, amount: 200000));
    await h.apply((l) => l.saveManualTrip('m', place: 'Camping', date: d(2026, 5, 1), amount: 1000));
    expect(accountsAndViews(await h.ledger(), today), before);
  });
}
