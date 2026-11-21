import 'dart:math';

import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/debt.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';

Matcher throwsLedger(LedgerError error) => throwsA(isA<LedgerException>().having((e) => e.error, 'error', error));

DebtDraft debt({
  DebtDirection direction = DebtDirection.owedToMe,
  String person = 'Alex Modèle',
  int amount = 20000,
  int basisPoints = 10000,
  CalendarDate? event,
  CalendarDate? invoice,
  CalendarDate? request,
  CalendarDate? received,
  String description = '',
  bool repaid = false,
}) => DebtDraft(
  direction: direction,
  person: person,
  amount: amount,
  basisPoints: basisPoints,
  eventDate: event,
  invoiceDate: invoice,
  requestDate: request,
  receivedDate: received,
  description: description,
  repaid: repaid,
);

void main() {
  late LedgerHarness h;
  setUp(() async => h = await LedgerHarness.open());
  tearDown(() => h.close());

  Future<Ledger> create(String id, DebtDraft draft, {required CalendarDate today}) =>
      h.apply((l) => l.createDebt(id, draft, today: today));

  test('the total is the amount times the percentage, rounded to the cent, halves away from zero: 200 at 50 % is '
      '100', () async {
    final ledger = await create('d', debt(amount: 20000, basisPoints: 5000), today: d(2026, 3, 1));
    expect(ledger.debts['d']!.total, 10000);
    expect(debtTotal(3333, 3333), 1111, reason: '33.33 × 33.33 % = 11.108889');
    expect(debtTotal(3, 5000), 2, reason: '0.015 rounds to 0.02');
    expect(debtTotal(1, 5000), 1);
    expect(debtTotal(1, 1), 0);
    expect(debtTotal(12345, 10000), 12345);
    expect((ledger.debts['d']!.basisPoints, debt().basisPoints), (5000, 10000), reason: '100 % by default');
  });

  test('a debt counts from the day of its event, or of its entry, to the day before its receipt, or before the day it '
      'was checked; unchecked, it counts again', () async {
    await create('event', debt(amount: 10000, event: d(2026, 3, 10)), today: d(2026, 3, 20));
    await create('entry', debt(amount: 1000, direction: DebtDirection.iOwe), today: d(2026, 3, 20));
    var ledger = await h.ledger();
    expect(ledger.openDebtsAt(d(2026, 3, 9)), 0);
    expect(ledger.openDebtsAt(d(2026, 3, 10)), 10000, reason: 'from the day of the event');
    expect(ledger.openDebtsAt(d(2026, 3, 19)), 10000);
    expect(ledger.openDebtsAt(d(2026, 3, 20)), 9000, reason: 'without event, from the day of entry');

    // Checked on 5.4, received on 1.4: counts until 31.3.
    ledger = await h.apply((l) => l.checkDebt('event', receivedDate: d(2026, 4, 1), today: d(2026, 4, 5)));
    expect((ledger.debts['event']!.repaid, ledger.debts['event']!.checkedOn), (true, d(2026, 4, 5)));
    expect(ledger.openDebtsAt(d(2026, 3, 31)), 9000);
    expect(ledger.openDebtsAt(d(2026, 4, 1)), -1000, reason: 'not on the day of receipt');

    // Checked without a date of receipt: until the day before it was checked.
    ledger = await h.apply((l) => l.checkDebt('entry', receivedDate: null, today: d(2026, 4, 10)));
    expect(ledger.openDebtsAt(d(2026, 4, 9)), -1000);
    expect(ledger.openDebtsAt(d(2026, 4, 10)), 0);

    // Unchecked: it counts again, its date of receipt kept.
    ledger = await h.apply((l) => l.uncheckDebt('event'));
    expect((ledger.debts['event']!.repaid, ledger.debts['event']!.checkedOn), (false, null));
    expect(ledger.debts['event']!.receivedDate, d(2026, 4, 1));
    expect(ledger.openDebtsAt(d(2030, 1, 1)), 10000);
  });

  test('the line « Dettes » is, at any date, the sum of the debts not repaid that count that day: on me doit adds, '
      'je dois takes away (specification, phase 5)', () async {
    await create('a', debt(amount: 20000, basisPoints: 5000, event: d(2026, 3, 1)), today: d(2026, 3, 5));
    await create('b', debt(amount: 8000, direction: DebtDirection.iOwe), today: d(2026, 3, 10));
    await create(
      'c',
      debt(amount: 5000, event: d(2026, 2, 1), received: d(2026, 4, 15), repaid: true),
      today: d(2026, 4, 20),
    );
    final ledger = await h.ledger();
    final cases = {
      d(2026, 1, 31): 0,
      d(2026, 2, 28): 5000,
      d(2026, 3, 1): 15000,
      d(2026, 3, 9): 15000,
      d(2026, 3, 10): 7000,
      d(2026, 4, 14): 7000,
      d(2026, 4, 15): 2000,
    };
    for (final MapEntry(key: date, value: total) in cases.entries) {
      expect(ledger.openDebtsAt(date), total, reason: '$date');
    }
    expect(ledger.debtTotalsAt(d(2026, 4, 1)), const DebtTotals(owedToMe: 15000, iOwe: 8000));
    expect(ledger.debtTotalsAt(d(2026, 4, 1)).net, 7000);
  });

  test('on random debts, the open debts at every date are the debts not repaid that count that day', () {
    for (var seed = 1; seed <= 10; seed++) {
      final r = Random(seed);
      CalendarDate day() => CalendarDate(2026, 1 + r.nextInt(12), 1 + r.nextInt(28));
      final debts = [
        for (var i = 0; i < 40; i++)
          () {
            final entered = day();
            final event = r.nextBool() ? day() : null;
            final repaid = r.nextInt(3) == 0;
            return Debt(
              id: 'd$i',
              direction: DebtDirection.values[r.nextInt(2)],
              person: 'P$i',
              amount: 1 + r.nextInt(100000),
              basisPoints: 1 + r.nextInt(10000),
              enteredOn: entered,
              eventDate: event,
              receivedDate: r.nextBool() ? day() : null,
              repaid: repaid,
              checkedOn: repaid && r.nextInt(4) > 0 ? day() : null,
            );
          }(),
      ];
      final ledger = Ledger(debts: debts);
      for (var date = d(2025, 12, 31); date.isBefore(d(2027, 1, 2)); date = date.addDays(1)) {
        var expected = 0;
        for (final debt in debts) {
          // Decision H5, read literally.
          final from = debt.eventDate ?? debt.enteredOn;
          final until = debt.receivedDate ?? debt.checkedOn;
          final open = !debt.repaid || (until != null && date.isBefore(until));
          if (open && !date.isBefore(from)) {
            final total = (debt.amount * debt.basisPoints * 2 + 10000) ~/ 20000;
            expected += debt.direction == DebtDirection.owedToMe ? total : -total;
          }
        }
        expect(ledger.openDebtsAt(date), expected, reason: 'seed $seed, $date');
      }
    }
  });

  test('splitting a debt gives two lines whose totals make the original total, to the cent; both keep direction, '
      'person, dates, description and state, at 100 %', () async {
    await create(
      'd',
      debt(
        amount: 20002,
        basisPoints: 5000,
        event: d(2026, 2, 1),
        invoice: d(2026, 2, 3),
        request: d(2026, 2, 10),
        received: d(2026, 3, 1),
        description: 'Billets de train',
        repaid: true,
      ),
      today: d(2026, 3, 2),
    );
    final before = (await h.ledger()).debts['d']!;
    expect(before.total, 10001);
    final ledger = await h.apply((l) => l.splitDebt('d', 'd2', 3333));
    final first = ledger.debts['d']!, second = ledger.debts['d2']!;
    expect((first.amount, first.basisPoints, first.total), (3333, 10000, 3333));
    expect((second.amount, second.basisPoints, second.total), (6668, 10000, 6668));
    expect(first.total + second.total, before.total);
    for (final part in [first, second]) {
      expect(
        (part.direction, part.person, part.eventDate, part.invoiceDate, part.requestDate, part.receivedDate),
        (
          before.direction,
          before.person,
          before.eventDate,
          before.invoiceDate,
          before.requestDate,
          before.receivedDate,
        ),
      );
      expect(
        (part.description, part.repaid, part.enteredOn, part.checkedOn),
        (before.description, before.repaid, before.enteredOn, before.checkedOn),
      );
    }
    for (var date = d(2026, 1, 31); date.isBefore(d(2026, 3, 3)); date = date.addDays(1)) {
      expect(ledger.openDebtsAt(date), Ledger(debts: [before]).openDebtsAt(date), reason: '$date');
    }
    for (final cents in [0, -1, 10001, 20000]) {
      expect(
        () => ledger.splitDebt('d2', 'd3', cents == 10001 ? 6668 : cents),
        throwsLedger(LedgerError.debtSplitOutOfTotal),
      );
    }
  });

  test('each refusal has its reason: no person, an amount of zero or less, a percentage out of 0.01 to 100 %, a '
      'receipt before the event, an unknown debt', () async {
    final ledger = await create('d', debt(), today: d(2026, 3, 1));
    final today = d(2026, 3, 1);
    expect(
      () => ledger.createDebt('x', debt(person: '  '), today: today),
      throwsLedger(LedgerError.debtPersonRequired),
    );
    expect(() => ledger.createDebt('x', debt(amount: 0), today: today), throwsLedger(LedgerError.amountRequired));
    expect(() => ledger.createDebt('x', debt(amount: -5), today: today), throwsLedger(LedgerError.amountRequired));
    expect(
      () => ledger.createDebt('x', debt(basisPoints: 0), today: today),
      throwsLedger(LedgerError.debtPercentInvalid),
    );
    expect(
      () => ledger.createDebt('x', debt(basisPoints: 10001), today: today),
      throwsLedger(LedgerError.debtPercentInvalid),
    );
    expect(
      () => ledger.createDebt(
        'x',
        debt(event: d(2026, 2, 2), received: d(2026, 2, 1)),
        today: today,
      ),
      throwsLedger(LedgerError.debtReceivedBeforeEvent),
    );
    expect(
      () => ledger.checkDebt('d', receivedDate: d(2026, 2, 1), today: today),
      returnsNormally,
      reason: 'without an event date, any date of receipt',
    );
    expect(() => ledger.updateDebt('x', debt(), today: today), throwsLedger(LedgerError.unknownDebt));
    expect(() => ledger.deleteDebt('x'), throwsLedger(LedgerError.unknownDebt));
    expect(() => ledger.checkDebt('x', receivedDate: today, today: today), throwsLedger(LedgerError.unknownDebt));
    expect(() => ledger.uncheckDebt('x'), throwsLedger(LedgerError.unknownDebt));
    expect(() => ledger.splitDebt('x', 'y', 1), throwsLedger(LedgerError.unknownDebt));
    expect(ledger.createDebt('x', debt(basisPoints: 1), today: today).changes, isNotEmpty);
    expect(
      ledger
          .createDebt(
            'x',
            debt(event: today, received: today),
            today: today,
          )
          .changes,
      isNotEmpty,
    );
  });

  test('a modification keeps the day the debt was checked unless its state changes; a debt is deleted; the list puts '
      'the debts not repaid first', () async {
    await create(
      'old',
      debt(event: d(2026, 1, 1), received: d(2026, 1, 20), repaid: true),
      today: d(2026, 1, 25),
    );
    await create(
      'new',
      debt(person: 'Camille Exemple', event: d(2026, 2, 1)),
      today: d(2026, 2, 1),
    );
    var ledger = await h.apply(
      (l) => l.updateDebt(
        'old',
        debt(event: d(2026, 1, 1), received: d(2026, 1, 21), repaid: true),
        today: d(2026, 6, 1),
      ),
    );
    expect((ledger.debts['old']!.checkedOn, ledger.debts['old']!.enteredOn), (d(2026, 1, 25), d(2026, 1, 25)));
    expect(ledger.sortedDebts.map((d) => d.id), ['new', 'old']);
    ledger = await h.apply((l) => l.updateDebt('old', debt(event: d(2026, 1, 1)), today: d(2026, 6, 1)));
    expect((ledger.debts['old']!.repaid, ledger.debts['old']!.checkedOn), (false, null));
    ledger = await h.apply(
      (l) => l.updateDebt('new', debt(person: 'Camille Exemple', repaid: true), today: d(2026, 6, 2)),
    );
    expect(ledger.debts['new']!.checkedOn, d(2026, 6, 2));
    ledger = await h.apply((l) => l.deleteDebt('old'));
    expect(ledger.debts.keys, ['new']);
  });

  test('known limit: the same debt split on two devices offline keeps both second parts, the first following the '
      'latest split', () async {
    var wallA = 1000, wallB = 1000;
    final a = await LedgerHarness.open(deviceId: 'aaaaaaaa-0000-4000-8000-000000000000', now: () => wallA);
    final b = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000', now: () => wallB);
    addTearDown(a.close);
    addTearDown(b.close);
    await a.apply((l) => l.createDebt('d', debt(amount: 10000), today: d(2026, 3, 1)));
    await b.journal.merge(await a.journal.entries());
    wallA = 5000;
    await a.apply((l) => l.splitDebt('d', 'from-a', 3000));
    wallB = 7000;
    await b.apply((l) => l.splitDebt('d', 'from-b', 4000));
    final fromA = await a.journal.entries(), fromB = await b.journal.entries();
    await a.journal.merge(fromB);
    await b.journal.merge(fromA);
    final ledger = await a.ledger();
    expect({for (final debt in ledger.debts.values) debt.id: debt.total}, {'d': 4000, 'from-a': 7000, 'from-b': 6000});
    expect(await a.tables(['debts']), await b.tables(['debts']));
  });
}
