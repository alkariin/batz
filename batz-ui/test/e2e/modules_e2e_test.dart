// The data of phase 6 between devices, through a real batz-web: what is
// entered in the modules on one device reaches another, which computes the
// same modules; the same salary sheet, fiscal year or kWh of a line entered
// on two devices offline gives one record.
import 'package:batz/domain/ids.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/modules/electricity.dart';
import 'package:batz/domain/modules/flow.dart';
import 'package:batz/domain/modules/salary.dart';
import 'package:batz/domain/modules/settings.dart';
import 'package:batz/domain/modules/subscriptions.dart';
import 'package:batz/domain/modules/taxes.dart';
import 'package:batz/domain/modules/vacations.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/modules/salary_test.dart' show exampleSheet;
import '../domain/modules/taxes_test.dart' show exampleTaxYear;
import '../support/ledger_fixture.dart';
import 'server_harness.dart';
import 'sync_device.dart';

const moduleTables = [
  'module_settings',
  'salary_sheets',
  'salary_deductions',
  'tax_years',
  'tax_lines',
  'trip_sheets',
  'electricity_readings',
  'subscriptions',
  'subscription_tranches',
];

void main() {
  late LocalServer server;
  late SimDevice a, b;
  var wallA = DateTime.utc(2026, 11, 21, 10).millisecondsSinceEpoch, wallB = wallA;

  setUp(() async {
    server = await LocalServer.start();
    a = await SimDevice.create('A', deviceId: 'aaaaaaaa-0000-4000-8000-000000000000', now: () => wallA);
    b = await SimDevice.create('B', deviceId: 'bbbbbbbb-0000-4000-8000-000000000000', now: () => wallB);
    for (final d in [a, b]) {
      await d.pair(server);
    }
    await seedLedger(a.ledger);
    final expenses = defaultGroupId(2026, CategoryNature.expense);
    await a.ledger.apply((l) => l.addCategory('trips', year: 2026, name: 'Vacances', parentId: expenses));
    await a.ledger.apply((l) => l.addCategory('power', year: 2026, name: 'Électricité', parentId: 'housing'));
    await a.ledger.apply((l) => l.addCategory('taxes', year: 2026, name: 'Impôts', parentId: expenses));
    await a.ledger.apply(
      (l) => l.recordEntry('trip', 'trip-line', entry(category: 'trips', cents: 64000, date: d(2026, 7, 10))),
    );
    await a.ledger.apply(
      (l) => l.recordEntry(
        'bill',
        'bill-line',
        entry(
          category: 'power',
          cents: 48000,
          date: d(2026, 5, 15),
          periodStart: d(2026, 1, 1),
          periodEnd: d(2026, 4, 30),
        ),
      ),
    );
    await a.ledger.apply(
      (l) => l.recordEntry('tax', 'tax-line', entry(category: 'taxes', cents: 120000, date: d(2026, 3, 20))),
    );
    await a.sync();
    await b.sync();
  });
  tearDown(() async {
    await a.close();
    await b.close();
    await server.stop();
    server.dataDir.deleteSync(recursive: true);
  });

  test('what is entered in every module on one device reaches the other, which computes the same modules', () async {
    final h = a.ledger;
    await h.apply((l) => l.setModuleCategory(ModuleKind.salary, 'Salaire'));
    await h.apply((l) => l.saveSalarySheet(exampleSheet(), newId: newId));
    await h.apply((l) => l.saveTaxYear(exampleTaxYear));
    await h.apply((l) => l.saveTrip(l.vacations.trips.single, place: 'Lisbonne', days: 14));
    await h.apply((l) => l.saveManualTrip('camp', place: 'Camping', date: d(2025, 8, 1), amount: 45000, days: 6));
    await h.apply((l) => l.setElectricity('bill-line', 1900000));
    await h.apply(
      (l) => l.createSubscription(
        's',
        's1',
        name: 'Streaming',
        first: TrancheDraft(amount: 1290, frequency: TrancheFrequency.monthly, start: d(2025, 3, 1)),
      ),
    );
    await h.apply(
      (l) => l.addTranche(
        's',
        's2',
        TrancheDraft(amount: 1490, frequency: TrancheFrequency.monthly, start: d(2026, 1, 1)),
      ),
    );
    await a.sync();
    await b.sync();

    final here = await a.ledger.ledger(), there = await b.ledger.ledger();
    expect(await b.ledger.tables(moduleTables), await a.ledger.tables(moduleTables));
    expect(there.salarySheet(2026)!.gap, 0);
    expect(
      (there.taxYear(2026).total, there.taxYear(2026).paid, there.taxYear(2026).shareOfGross),
      (1503380, 120000, 1566),
    );
    expect(
      [for (final t in there.vacations.trips) (t.place, t.amount, t.pricePerDay)],
      [for (final t in here.vacations.trips) (t.place, t.amount, t.pricePerDay)],
    );
    expect(there.vacations.trips.map((t) => t.place), ['Lisbonne', 'Camping']);
    final power = there.electricityYear(2026);
    expect((power.price, power.wh, power.days), (48000, 1900000, 120));
    expect(there.subscriptionsAt(d(2026, 11, 21)).monthlyTotal, 1490);
    final diagram = flowDiagram(there, 2026, ViewKind.economic)!;
    expect((diagram.fromGross, diagram.leftTotal), (true, flowDiagram(here, 2026, ViewKind.economic)!.leftTotal));

    // Deleted on B: A follows.
    await b.ledger.apply((l) => l.deleteSalarySheet(2026));
    await b.ledger.apply((l) => l.setElectricity('bill-line', null));
    await b.sync();
    await a.sync();
    final back = await a.ledger.ledger();
    expect((back.salarySheet(2026), back.electricityYear(2026).wh), (null, 0));
    expect(await b.ledger.tables(moduleTables), await a.ledger.tables(moduleTables));
  });

  test(
    'the same salary sheet, fiscal year or kWh of a line entered on two devices offline write one record each',
    () async {
      wallA += 1000;
      await a.ledger.apply((l) => l.saveSalarySheet(exampleSheet(), newId: newId));
      await a.ledger.apply((l) => l.saveTaxYear(exampleTaxYear));
      await a.ledger.apply((l) => l.setElectricity('bill-line', 1900000));
      wallB += 2000;
      await b.ledger.apply((l) => l.saveSalarySheet(exampleSheet(net: 8380000), newId: newId));
      await b.ledger.apply((l) => l.saveTaxYear(const TaxYearDraft(year: 2026, taxableWealth: 1)));
      await b.ledger.apply((l) => l.setElectricity('bill-line', 2000000));
      await a.sync();
      await b.sync();
      await a.sync();
      for (final device in [a, b]) {
        final ledger = await device.ledger.ledger();
        expect(ledger.modules.salarySheets.keys, [2026], reason: device.name);
        expect(ledger.salarySheet(2026)!.net, 8380000);
        expect(ledger.taxYears, [2026]);
        expect(ledger.modules.taxLines[2026], hasLength(5));
        expect(ledger.taxYear(2026).record!.taxableWealth, 1);
        expect(ledger.modules.electricityReadings.values.map((r) => r.wh), [2000000]);
      }
      final tables = await a.ledger.tables(['salary_sheets', 'tax_years', 'tax_lines', 'electricity_readings']);
      expect(await b.ledger.tables(['salary_sheets', 'tax_years', 'tax_lines', 'electricity_readings']), tables);
      expect([for (final rows in tables.values) rows.length], [1, 1, 5, 1]);
    },
  );
}
