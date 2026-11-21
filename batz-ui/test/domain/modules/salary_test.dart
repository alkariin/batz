import 'package:batz/domain/ids.dart';
import 'package:batz/domain/ledger/balance.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/salary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/module_checks.dart';

Matcher throwsLedger(LedgerError error) => throwsA(isA<LedgerException>().having((e) => e.error, 'error', error));

/// The sheet of the reference example.
SalarySheetDraft exampleSheet({int year = 2026, int net = 8385600}) => SalarySheetDraft(
  year: year,
  gross: 9600000,
  net: net,
  deductions: const [
    DeductionDraft(label: 'AVS', amount: 508800),
    DeductionDraft(label: 'AC', amount: 105600),
    DeductionDraft(label: 'LPP', amount: 600000),
  ],
);

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
  });
  tearDown(() => h.close());

  test('the example: 96\'000.00 gross, 12\'144.00 of deductions and 83\'856.00 net leave a gap of 0.00; with a '
      'net of 83\'800.00, of 56.00', () async {
    var ledger = await h.apply((l) => l.saveSalarySheet(exampleSheet(), newId: newId));
    var sheet = ledger.salarySheet(2026)!;
    expect(sheet.id, salarySheetId(2026));
    expect(sheet.deductions.map((d) => (d.label, d.amount, d.rank)), [
      ('AVS', 508800, 0),
      ('AC', 105600, 1),
      ('LPP', 600000, 2),
    ]);
    expect((sheet.deductionsTotal, sheet.gap), (1214400, 0));

    ledger = await h.apply((l) => l.saveSalarySheet(exampleSheet(net: 8380000), newId: newId));
    sheet = ledger.salarySheet(2026)!;
    expect(sheet.gap, 5600, reason: 'shown, never refused');
    expect(sheet.deductions, hasLength(3), reason: 'no new deduction: the form sends their identifiers');
  });

  test('deductions are added, modified, moved and removed; the sheet is deleted with them, and comes back', () async {
    await h.apply((l) => l.saveSalarySheet(exampleSheet(), newId: newId));
    var sheet = (await h.ledger()).salarySheet(2026)!;
    final [avs, ac, lpp] = sheet.deductions;
    var ledger = await h.apply(
      (l) => l.saveSalarySheet(
        SalarySheetDraft(
          year: 2026,
          gross: 9600000,
          net: 8385600,
          deductions: [
            DeductionDraft(id: lpp.id, label: 'LPP', amount: 610000),
            DeductionDraft(id: avs.id, label: 'AVS', amount: 508800),
            const DeductionDraft(label: 'AANP', amount: 20000),
          ],
        ),
        newId: newId,
      ),
    );
    sheet = ledger.salarySheet(2026)!;
    expect(sheet.deductions.map((d) => (d.label, d.amount)), [('LPP', 610000), ('AVS', 508800), ('AANP', 20000)]);
    expect(sheet.deductions.map((d) => d.id), isNot(contains(ac.id)));
    expect(sheet.gap, 9600000 - 610000 - 508800 - 20000 - 8385600);

    ledger = await h.apply((l) => l.deleteSalarySheet(2026));
    expect(ledger.salarySheet(2026), isNull);
    expect(ledger.modules.salarySheets, isEmpty);
    ledger = await h.apply((l) => l.saveSalarySheet(exampleSheet(), newId: newId));
    expect(ledger.salarySheet(2026)!.deductions, hasLength(3));
  });

  test('each refusal has its reason: a gross of zero or less, a negative net, a deduction without label or '
      'negative', () async {
    final ledger = await h.ledger();
    SalarySheetDraft draft({int gross = 100, int net = 50, String label = 'AVS', int amount = 10}) => SalarySheetDraft(
      year: 2026,
      gross: gross,
      net: net,
      deductions: [DeductionDraft(label: label, amount: amount)],
    );
    expect(() => ledger.saveSalarySheet(draft(gross: 0), newId: newId), throwsLedger(LedgerError.salaryGrossRequired));
    expect(() => ledger.saveSalarySheet(draft(gross: -1), newId: newId), throwsLedger(LedgerError.salaryGrossRequired));
    expect(() => ledger.saveSalarySheet(draft(net: -1), newId: newId), throwsLedger(LedgerError.salaryNetNegative));
    expect(
      () => ledger.saveSalarySheet(draft(label: ' '), newId: newId),
      throwsLedger(LedgerError.salaryDeductionLabelRequired),
    );
    expect(
      () => ledger.saveSalarySheet(draft(amount: -1), newId: newId),
      throwsLedger(LedgerError.salaryDeductionNegative),
    );
    expect(() => ledger.deleteSalarySheet(2026), throwsLedger(LedgerError.unknownSalarySheet));
    expect(ledger.saveSalarySheet(draft(net: 0, amount: 0), newId: newId).changes, isNotEmpty);
  });

  test('a new sheet proposes the labels of the closest earlier sheet, otherwise AVS, AC and LPP', () async {
    var ledger = await h.ledger();
    expect(ledger.proposedDeductionLabels(2026), ['AVS', 'AC', 'LPP']);
    ledger = await h.apply(
      (l) => l.saveSalarySheet(
        const SalarySheetDraft(
          year: 2024,
          gross: 100,
          net: 90,
          deductions: [
            DeductionDraft(label: 'AVS/AI/APG', amount: 5),
            DeductionDraft(label: 'LPP', amount: 5),
          ],
        ),
        newId: newId,
      ),
    );
    expect(ledger.proposedDeductionLabels(2026), ['AVS/AI/APG', 'LPP']);
    expect(ledger.proposedDeductionLabels(2024), ['AVS', 'AC', 'LPP']);
  });

  test('two devices creating the sheet of the same year write one sheet', () async {
    var wallA = 1000, wallB = 1000;
    final a = await LedgerHarness.open(deviceId: 'aaaaaaaa-0000-4000-8000-000000000000', now: () => wallA);
    final b = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000', now: () => wallB);
    addTearDown(a.close);
    addTearDown(b.close);
    wallA = 5000;
    await a.apply((l) => l.saveSalarySheet(exampleSheet(), newId: newId));
    wallB = 7000;
    await b.apply((l) => l.saveSalarySheet(exampleSheet(net: 8380000), newId: newId));
    final fromA = await a.journal.entries(), fromB = await b.journal.entries();
    await a.journal.merge(fromB);
    await b.journal.merge(fromA);
    for (final device in [a, b]) {
      final ledger = await device.ledger();
      expect(ledger.modules.salarySheets.keys, [2026]);
      expect(ledger.salarySheet(2026)!.net, 8380000, reason: 'the latest');
    }
    expect(
      await a.tables(['salary_sheets', 'salary_deductions']),
      await b.tables(['salary_sheets', 'salary_deductions']),
    );
    // Known limit: the deductions each device created are both kept.
    expect((await a.ledger()).salarySheet(2026)!.deductions, hasLength(6));
  });

  test('a salary sheet changes neither the annual views nor the wealth', () async {
    final today = d(2026, 11, 21);
    await h.apply(
      (l) => l.recordEntry(
        'salary',
        'ls',
        entry(category: 'salary', cents: 698800, direction: Direction.inflow, date: d(2026, 1, 25)),
      ),
    );
    await h.apply((l) => l.declareBalance('cash', d(2025, 12, 31), 100000, today: today));
    final before = accountsAndViews(await h.ledger(), today);
    await h.apply((l) => l.saveSalarySheet(exampleSheet(), newId: newId));
    expect(accountsAndViews(await h.ledger(), today), before);
  });
}
