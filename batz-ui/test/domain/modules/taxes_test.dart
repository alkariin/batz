import 'dart:math';

import 'package:batz/domain/ids.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/modules/module_records.dart';
import 'package:batz/domain/modules/salary.dart';
import 'package:batz/domain/modules/taxes.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/module_checks.dart';
import 'salary_test.dart' show exampleSheet;

Matcher throwsLedger(LedgerError error) => throwsA(isA<LedgerException>().having((e) => e.error, 'error', error));

/// The fiscal year 2026 of the example of the plan.
const exampleTaxYear = TaxYearDraft(
  year: 2026,
  taxableWealth: 20000000,
  marginalRate: 3150,
  lines: {
    TaxKind.federalIncome: TaxLineDraft(base: 8000000, baseRate: 25000),
    TaxKind.cantonalIncome: TaxLineDraft(base: 7800000, baseRate: 65000, coefficient: 15500),
    TaxKind.communalIncome: TaxLineDraft(base: 7800000, baseRate: 65000, coefficient: 7900),
    TaxKind.cantonalWealth: TaxLineDraft(baseRate: 2500, coefficient: 15500),
    TaxKind.communalWealth: TaxLineDraft(baseRate: 2500, coefficient: 7900),
  },
);

/// « Impôts » under the expenses of 2026, and the payments of the control
/// of the example: ten instalments of 1'200.00 in 2026 for 2026; 3'000.00
/// paid on 15.4.2027 for 2026; 2'500.00 paid in 2026 for 2025.
Future<Ledger> taxPayments(LedgerHarness h) async {
  await h.apply(
    (l) => l.addCategory('taxes', year: 2026, name: 'Impôts', parentId: defaultGroupId(2026, CategoryNature.expense)),
  );
  for (var month = 1; month <= 10; month++) {
    await h.apply(
      (l) => l.recordEntry('t$month', 'l$month', entry(category: 'taxes', cents: 120000, date: d(2026, month, 20))),
    );
  }
  await h.apply(
    (l) => l.recordEntry(
      'old',
      'l-old',
      entry(
        category: 'taxes',
        cents: 250000,
        date: d(2026, 3, 31),
        periodStart: d(2025, 1, 1),
        periodEnd: d(2025, 12, 31),
      ),
    ),
  );
  final taxes2027 = (await h.ledger()).treeOrPreview(2027).named('Impôts')!.id;
  return h.apply(
    (l) => l.recordEntry(
      'final',
      'l-final',
      entry(
        category: taxes2027,
        cents: 300000,
        date: d(2027, 4, 15),
        periodStart: d(2026, 1, 1),
        periodEnd: d(2026, 12, 31),
      ),
    ),
  );
}

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
  });
  tearDown(() => h.close());

  test('the example, line by line: 15\'033.80 in all, 15.66 % of the gross and 17.93 % of the net', () async {
    await h.apply((l) => l.saveSalarySheet(exampleSheet(), newId: newId));
    final ledger = await h.apply((l) => l.saveTaxYear(exampleTaxYear));
    final year = ledger.taxYear(2026);
    expect(
      [for (final line in year.lines) (line.tax, line.base, line.totalRate, line.amount)],
      [
        (TaxKind.federalIncome, 8000000, 25000, 200000),
        (TaxKind.cantonalIncome, 7800000, 100750, 785850),
        (TaxKind.communalIncome, 7800000, 51350, 400530),
        (TaxKind.cantonalWealth, 20000000, 3875, 77500),
        (TaxKind.communalWealth, 20000000, 1975, 39500),
      ],
    );
    expect(year.total, 1503380);
    expect(year.total, year.lines.fold(0, (s, l) => s + l.amount));
    expect((year.shareOfGross, year.shareOfNet), (1566, 1793));
    expect(year.record!.marginalRate, 3150);
    expect(ledger.taxYears, [2026]);
  });

  test('the control uses the period, not the date of payment: 15\'000.00 paid for 2026, 33.80 left to pay; the '
      'cash-flow view of 2026 shows 14\'500.00', () async {
    await taxPayments(h);
    final ledger = await h.apply((l) => l.saveTaxYear(exampleTaxYear));
    final year = ledger.taxYear(2026);
    expect((year.categoryFound, year.paid, year.gap), (true, 1500000, 3380));
    expect(ledger.views.of(2026, ViewKind.cash)!.totalOf('taxes'), -1450000);
    expect(ledger.views.of(2026, ViewKind.economic)!.totalOf('taxes'), -1500000);
    expect(year.shareOfGross, isNull, reason: 'no salary sheet for 2026');
    expect(year.shareOfNet, isNull);
  });

  test('a fiscal year before the first tree is entered, without control', () async {
    await taxPayments(h);
    final ledger = await h.apply(
      (l) => l.saveTaxYear(
        const TaxYearDraft(year: 2025, lines: {TaxKind.federalIncome: TaxLineDraft(base: 100000, baseRate: 10000)}),
      ),
    );
    final year = ledger.taxYear(2025);
    expect((year.total, year.paid, year.gap, year.categoryFound), (1000, null, null, false));
    expect(ledger.taxYear(2024).record, isNull);
    expect(ledger.taxYear(2024).total, 0);
  });

  test('one rounding per amount, halves away from zero; an incomplete line counts 0', () async {
    expect(taxAmount(1, 500000, 10000), 1, reason: '0.5 cent');
    expect(taxAmount(3, 500000, 10000), 2, reason: '1.5 cents');
    expect(taxAmount(5, 100000, 10000), 1, reason: '0.5 cent');
    expect(taxAmount(4, 100000, 10000), 0, reason: '0.4 cent');
    expect(taxAmount(333, 333333, 15000), 166, reason: '166.4998… cents');
    expect(taxAmount(333, 333334, 15000), 167, reason: '166.50… cents');
    expect(totalRate(65000, 7900), 51350);
    expect(totalRate(33333, 3333), 11110, reason: '11.10998… thousandths');
    final ledger = await h.apply(
      (l) => l.saveTaxYear(
        const TaxYearDraft(
          year: 2026,
          lines: {
            TaxKind.federalIncome: TaxLineDraft(base: 100000),
            TaxKind.cantonalWealth: TaxLineDraft(baseRate: 1000),
          },
        ),
      ),
    );
    expect(ledger.taxYear(2026).lines.map((l) => l.amount), [0, 0, 0, 0, 0], reason: 'no rate; no taxable wealth');
  });

  test('on random data, each amount is base × rate × coefficient rounded once, and the total is the sum of the '
      'lines', () {
    for (var seed = 1; seed <= 200; seed++) {
      final r = Random(seed);
      final years = [
        for (var y = 2020; y < 2026; y++)
          TaxYear(id: taxYearId(y), year: y, taxableWealth: r.nextBool() ? r.nextInt(100000000) : null),
      ];
      final lines = [
        for (final year in years)
          for (final tax in TaxKind.values)
            if (r.nextInt(5) > 0)
              TaxLine(
                id: taxLineId(year.year, tax),
                year: year.year,
                tax: tax,
                base: r.nextBool() ? r.nextInt(50000000) : null,
                baseRate: r.nextInt(6) > 0 ? r.nextInt(200000) : null,
                coefficient: r.nextInt(30000),
              ),
      ];
      final ledger = Ledger(
        modules: ModuleRecords(taxYears: years, taxLines: lines),
      );
      for (final year in years) {
        final result = ledger.taxYear(year.year);
        for (final line in result.lines) {
          final record = lines.where((l) => l.year == year.year && l.tax == line.tax).firstOrNull;
          final base = line.tax.onWealth ? year.taxableWealth : record?.base;
          final rate = record?.baseRate;
          final expected = base == null || rate == null
              ? 0
              : ((BigInt.from(base) * BigInt.from(rate) * BigInt.from(record!.coefficient!) * BigInt.two +
                            BigInt.from(10).pow(10)) ~/
                        (BigInt.from(10).pow(10) * BigInt.two))
                    .toInt();
          expect(line.amount, expected, reason: 'seed $seed, ${year.year} ${line.tax.name}');
        }
        expect(result.total, result.lines.fold(0, (s, l) => s + l.amount));
      }
    }
  });

  test('each refusal has its reason: a negative base, a rate out of 0 to 100 %, a negative coefficient, a marginal '
      'rate out of 0 to 100 %', () async {
    final ledger = await h.ledger();
    TaxYearDraft line(TaxLineDraft draft) => TaxYearDraft(year: 2026, lines: {TaxKind.federalIncome: draft});
    expect(() => ledger.saveTaxYear(line(const TaxLineDraft(base: -1))), throwsLedger(LedgerError.taxBaseNegative));
    expect(
      () => ledger.saveTaxYear(const TaxYearDraft(year: 2026, taxableWealth: -1)),
      throwsLedger(LedgerError.taxBaseNegative),
    );
    expect(() => ledger.saveTaxYear(line(const TaxLineDraft(baseRate: -1))), throwsLedger(LedgerError.taxRateInvalid));
    expect(
      () => ledger.saveTaxYear(line(const TaxLineDraft(baseRate: 1000001))),
      throwsLedger(LedgerError.taxRateInvalid),
    );
    expect(
      () => ledger.saveTaxYear(line(const TaxLineDraft(coefficient: -1))),
      throwsLedger(LedgerError.taxCoefficientNegative),
    );
    expect(
      () => ledger.saveTaxYear(const TaxYearDraft(year: 2026, marginalRate: 10001)),
      throwsLedger(LedgerError.taxMarginalRateInvalid),
    );
    expect(
      () => ledger.saveTaxYear(const TaxYearDraft(year: 2026, marginalRate: -1)),
      throwsLedger(LedgerError.taxMarginalRateInvalid),
    );
    expect(() => ledger.deleteTaxYear(2026), throwsLedger(LedgerError.unknownTaxYear));
    expect(
      ledger.saveTaxYear(line(const TaxLineDraft(base: 0, baseRate: 1000000, coefficient: 0))).changes,
      isNotEmpty,
    );
  });

  test('a fiscal year is modified and deleted with its lines', () async {
    await h.apply((l) => l.saveTaxYear(exampleTaxYear));
    var ledger = await h.apply(
      (l) => l.saveTaxYear(
        const TaxYearDraft(
          year: 2026,
          taxableWealth: 10000000,
          lines: {TaxKind.cantonalWealth: TaxLineDraft(baseRate: 2500, coefficient: 15500)},
        ),
      ),
    );
    final year = ledger.taxYear(2026);
    expect(year.lines.map((l) => l.amount), [0, 0, 0, 38750, 0]);
    expect(year.record!.marginalRate, isNull);
    ledger = await h.apply((l) => l.deleteTaxYear(2026));
    expect((ledger.taxYears.isEmpty, ledger.modules.taxLines.isEmpty), (true, true));
  });

  test('two devices entering the same fiscal year write one year and one record per line', () async {
    var wallA = 1000, wallB = 1000;
    final a = await LedgerHarness.open(deviceId: 'aaaaaaaa-0000-4000-8000-000000000000', now: () => wallA);
    final b = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000', now: () => wallB);
    addTearDown(a.close);
    addTearDown(b.close);
    wallA = 5000;
    await a.apply((l) => l.saveTaxYear(exampleTaxYear));
    wallB = 7000;
    await b.apply(
      (l) => l.saveTaxYear(
        const TaxYearDraft(
          year: 2026,
          taxableWealth: 1,
          lines: {TaxKind.federalIncome: TaxLineDraft(base: 1, baseRate: 1)},
        ),
      ),
    );
    final fromA = await a.journal.entries(), fromB = await b.journal.entries();
    await a.journal.merge(fromB);
    await b.journal.merge(fromA);
    for (final device in [a, b]) {
      final ledger = await device.ledger();
      expect(ledger.taxYears, [2026]);
      expect(ledger.modules.taxLines[2026], hasLength(5));
      expect(ledger.taxYear(2026).record!.taxableWealth, 1, reason: 'the latest');
    }
    expect(await a.tables(['tax_years', 'tax_lines']), await b.tables(['tax_years', 'tax_lines']));
  });

  test('a fiscal year changes neither the annual views nor the wealth', () async {
    final today = d(2026, 11, 21);
    await taxPayments(h);
    final before = accountsAndViews(await h.ledger(), today);
    await h.apply((l) => l.saveTaxYear(exampleTaxYear));
    expect(accountsAndViews(await h.ledger(), today), before);
  });

  test('a fiscal year uses the salary sheet of its own year only', () async {
    await h.apply((l) => l.saveSalarySheet(exampleSheet(year: 2025), newId: newId));
    final ledger = await h.apply((l) => l.saveTaxYear(exampleTaxYear));
    expect(ledger.taxYear(2026).shareOfGross, isNull);
    expect(ledger.salarySheet(2025), isNotNull);
  });
}
