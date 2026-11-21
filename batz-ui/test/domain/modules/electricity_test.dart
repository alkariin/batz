import 'dart:math';

import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/electricity.dart';
import 'package:batz/domain/modules/module_records.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/module_checks.dart';

Matcher throwsLedger(LedgerError error) => throwsA(isA<LedgerException>().having((e) => e.error, 'error', error));

/// « Électricité » under « Logement » of 2026, and the three invoices of
/// the example of the plan with their kWh.
Future<Ledger> electricityExample(LedgerHarness h) async {
  await h.apply((l) => l.addCategory('power', year: 2026, name: 'Électricité', parentId: 'housing'));
  await h.apply(
    (l) => l.recordEntry(
      'i1',
      'i1-l',
      entry(
        category: 'power',
        cents: 48000,
        date: d(2026, 5, 15),
        periodStart: d(2026, 1, 1),
        periodEnd: d(2026, 4, 30),
      ),
    ),
  );
  await h.apply(
    (l) => l.recordEntry(
      'i2',
      'i2-l',
      entry(
        category: 'power',
        cents: 54000,
        date: d(2026, 11, 15),
        periodStart: d(2026, 5, 1),
        periodEnd: d(2026, 10, 31),
      ),
    ),
  );
  final power2027 = (await h.ledger()).treeOrPreview(2027).named('Électricité')!.id;
  await h.apply(
    (l) => l.recordEntry(
      'i3',
      'i3-l',
      entry(
        category: power2027,
        cents: 30000,
        date: d(2027, 1, 20),
        periodStart: d(2026, 11, 1),
        periodEnd: d(2027, 1, 31),
      ),
    ),
  );
  for (final (line, kwh) in [('i1-l', 1900), ('i2-l', 2000), ('i3-l', 1200)]) {
    await h.apply((l) => l.setElectricity(line, kwh * 1000));
  }
  return h.ledger();
}

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
  });
  tearDown(() => h.close());

  test('the example, year by year: 2026 1\'220.00, 4\'700 kWh, 365 days, 3.34, 0.2596 and 12.88; 2027 100.00, '
      '400 kWh, 31 days', () async {
    final ledger = await electricityExample(h);
    final y2026 = ledger.electricityYear(2026), y2027 = ledger.electricityYear(2027);
    expect(
      (y2026.price, y2026.wh, y2026.days, y2026.pricePerDay, y2026.pricePerKwh, y2026.kwhPerDay),
      (122000, 4700000, 365, 334, 2596, 1288),
    );
    expect(
      (y2027.price, y2027.wh, y2027.days, y2027.pricePerDay, y2027.pricePerKwh, y2027.kwhPerDay),
      (10000, 400000, 31, 323, 2500, 1290),
    );
    expect(
      ledger.views.of(2026, ViewKind.cash)!.totalOf('power'),
      -102000,
      reason: 'the module reads the economic view',
    );
    expect(ledger.electricityYears(currentYear: 2026), [2026, 2027]);
    expect(y2026.linesWithoutKwh, 0);
    final third = y2026.lines.singleWhere((l) => l.line.ownLineId == 'i3-l');
    expect((third.amount, third.whInYear, third.days), (20000, 800000, 92));
  });

  test('an instalment and a final invoice over the same days count them once; a line without kWh is counted', () async {
    await h.apply((l) => l.addCategory('power', year: 2026, name: 'Électricité', parentId: 'housing'));
    await h.apply(
      (l) => l.recordEntry(
        'a',
        'a-l',
        entry(
          category: 'power',
          cents: 30000,
          date: d(2026, 3, 1),
          periodStart: d(2026, 1, 1),
          periodEnd: d(2026, 6, 30),
        ),
      ),
    );
    var ledger = await h.apply(
      (l) => l.recordEntry(
        'b',
        'b-l',
        entry(
          category: 'power',
          cents: 5000,
          date: d(2026, 7, 10),
          periodStart: d(2026, 1, 1),
          periodEnd: d(2026, 6, 30),
        ),
      ),
    );
    ledger = await h.apply((l) => l.setElectricity('b-l', 1500000));
    final year = ledger.electricityYear(2026);
    expect((year.days, year.price, year.wh, year.linesWithoutKwh), (181, 35000, 1500000, 1));
  });

  test('the kWh of a line are entered, modified and erased; negative ones are refused; kWh left on a line that '
      'left the category are listed apart', () async {
    var ledger = await electricityExample(h);
    expect(() => ledger.setElectricity('i1-l', -1), throwsLedger(LedgerError.electricityNegative));
    ledger = await h.apply((l) => l.setElectricity('i1-l', 2000000));
    expect(ledger.electricityYear(2026).wh, 4800000);
    ledger = await h.apply((l) => l.setElectricity('i1-l', null));
    expect((ledger.electricityYear(2026).wh, ledger.electricityYear(2026).linesWithoutKwh), (2800000, 1));
    expect(() => ledger.setElectricity('i1-l', null), throwsLedger(LedgerError.unknownElectricityReading));
    ledger = await h.apply((l) => l.updateEntry('i2', entry(category: 'food', cents: 54000, date: d(2026, 11, 15))));
    expect(ledger.orphanReadings.map((r) => r.lineId), ['i2-l']);
    expect(ledger.electricityYear(2026).price, 48000 + 20000);
  });

  test('a category missing from a year: nothing for that year, without error', () async {
    final ledger = await h.ledger();
    final year = ledger.electricityYear(2026);
    expect((year.categoryFound, year.lines.isEmpty, year.pricePerDay, year.pricePerKwh), (false, true, null, null));
  });

  test('on random data, for each year, the price is the total of the category in the economic view, and the kWh '
      'spread make the kWh entered', () {
    for (var seed = 1; seed <= 30; seed++) {
      final r = Random(seed);
      final categories = [
        for (final year in [2026, 2027]) ...[
          Category(id: 'in-$year', year: year, name: 'Revenus', nature: CategoryNature.income, position: 0),
          Category(id: 'out-$year', year: year, name: 'Dépenses', nature: CategoryNature.expense, position: 1),
          Category(id: 'home-$year', year: year, name: 'Logement', parentId: 'out-$year', position: 0),
          Category(id: 'power-$year', year: year, name: 'Électricité', parentId: 'home-$year', position: 0),
          Category(id: 'rent-$year', year: year, name: 'Loyer', parentId: 'home-$year', position: 1),
        ],
      ];
      final transactions = <LedgerTransaction>[], lines = <TransactionLine>[], readings = <ElectricityReading>[];
      var entered = 0;
      for (var i = 0; i < 40; i++) {
        final year = 2026 + r.nextInt(2);
        final date = CalendarDate(year, 1 + r.nextInt(12), 1 + r.nextInt(28));
        final start = date.addDays(-r.nextInt(120));
        final startIn = start.year < 2026 ? CalendarDate(2026, 1, 1) : start;
        var end = startIn.addDays(r.nextInt(200));
        if (end.year > 2027) end = CalendarDate(2027, 12, 31);
        final amount = (r.nextInt(8) == 0 ? 1 : -1) * (1 + r.nextInt(80000));
        final category = r.nextInt(5) == 0 ? 'rent-$year' : 'power-$year';
        transactions.add(LedgerTransaction(id: 't$i', accountId: 'cash', date: date, amount: amount));
        lines.add(
          TransactionLine(
            id: 't$i-l',
            transactionId: 't$i',
            categoryId: category,
            amount: amount,
            periodStart: startIn,
            periodEnd: end,
          ),
        );
        if (r.nextInt(4) > 0) {
          final wh = r.nextInt(3000000);
          readings.add(ElectricityReading(id: electricityReadingId('t$i-l'), lineId: 't$i-l', wh: wh));
          if (category.startsWith('power')) entered += wh;
        }
      }
      final ledger = Ledger(
        accounts: const [Account(id: 'cash', name: 'Compte', type: AccountType.cash)],
        categories: categories,
        transactions: transactions,
        lines: lines,
        modules: ModuleRecords(electricityReadings: readings),
      );
      var spread = 0;
      for (final year in [2026, 2027]) {
        final result = ledger.electricityYear(year);
        expect(
          result.price,
          -ledger.views.of(year, ViewKind.economic)!.totalOf('power-$year'),
          reason: 'seed $seed, $year',
        );
        spread += result.wh;
        expect(result.days, lessThanOrEqualTo(CalendarDate.isLeapYear(year) ? 366 : 365));
      }
      expect(spread, entered, reason: 'seed $seed');
      expect(ledger.orphanReadings.map((r) => r.lineId).toSet(), {
        for (final line in lines)
          if (line.categoryId!.startsWith('rent') && readings.any((r) => r.lineId == line.id)) line.id,
      });
    }
  });

  test('two devices entering the kWh of the same line write one record', () async {
    var wallA = 1000, wallB = 1000;
    final a = await LedgerHarness.open(deviceId: 'aaaaaaaa-0000-4000-8000-000000000000', now: () => wallA);
    final b = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000', now: () => wallB);
    addTearDown(a.close);
    addTearDown(b.close);
    wallA = 5000;
    await a.apply((l) => l.setElectricity('line-1', 1000000));
    wallB = 7000;
    await b.apply((l) => l.setElectricity('line-1', 1200000));
    final fromA = await a.journal.entries(), fromB = await b.journal.entries();
    await a.journal.merge(fromB);
    await b.journal.merge(fromA);
    for (final device in [a, b]) {
      expect((await device.ledger()).modules.electricityReadings.values.map((r) => r.wh), [1200000]);
    }
    expect(await a.tables(['electricity_readings']), await b.tables(['electricity_readings']));
  });

  test('kWh change neither the annual views nor the wealth', () async {
    final today = d(2026, 11, 21);
    await electricityExample(h);
    await h.apply((l) => l.setElectricity('i1-l', null));
    final before = accountsAndViews(await h.ledger(), today);
    await h.apply((l) => l.setElectricity('i1-l', 1900000));
    expect(accountsAndViews(await h.ledger(), today), before);
  });
}
