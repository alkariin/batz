import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ids.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/salary.dart';
import 'package:batz/domain/modules/taxes.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show settle;

void main() {
  late AppServices services;

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  Future<void> write(WidgetTester tester, Modification Function(Ledger l) build) =>
      tester.runAsync(() async => services.ledger.write(build(await services.ledger.load())));

  testWidgets('the fiscal year of the example: each line as typed, 15\'033.80, its shares of the salary, the '
      'control against the economic view, the summary', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = (await tester.runAsync(() => testServices(today: () => CalendarDate(2026, 11, 21))))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await write(tester, (l) => l.createAccount('cash', const AccountDraft(name: 'Compte', type: AccountType.cash)));
    await write(tester, (l) => l.createTree(2026));
    await write(
      tester,
      (l) => l.addCategory('taxes', year: 2026, name: 'Impôts', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
    for (var month = 1; month <= 10; month++) {
      await write(
        tester,
        (l) => l.recordEntry(
          't$month',
          'l$month',
          EntryDraft(
            accountId: 'cash',
            date: CalendarDate(2026, month, 20),
            cents: 120000,
            direction: Direction.outflow,
            categoryId: 'taxes',
          ),
        ),
      );
    }
    await write(
      tester,
      (l) => l.saveSalarySheet(
        const SalarySheetDraft(
          year: 2026,
          gross: 9600000,
          net: 8385600,
          deductions: [
            DeductionDraft(label: 'AVS', amount: 508800),
            DeductionDraft(label: 'AC', amount: 105600),
            DeductionDraft(label: 'LPP', amount: 600000),
          ],
        ),
        newId: newId,
      ),
    );
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('moreTaxes')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('taxesYear')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026').last);
    await tester.pumpAndSettle();
    expect(find.text("Trouvée dans l'arbre de 2026."), findsOneWidget);

    Future<void> type(String key, String value) async {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.enterText(find.byKey(ValueKey(key)), value);
      await tester.pump();
    }

    await type('taxesWealth', "200'000");
    await type('taxesMarginal', '31.5');
    for (final (tax, base, rate, coefficient) in [
      ('federalIncome', "80'000", '2.5', '100'),
      ('cantonalIncome', "78'000", '6.5', '155'),
      ('communalIncome', "78'000", '6.5', '79'),
      ('cantonalWealth', null, '0.25', '155'),
      ('communalWealth', null, '0.25', '79'),
    ]) {
      if (base != null) await type('taxesBase-$tax', base);
      await type('taxesRate-$tax', rate);
      await type('taxesCoefficient-$tax', coefficient);
    }
    expect(text(tester, 'taxesLine-federalIncome'), "Taux total 2.5000 % · 2'000.00");
    expect(text(tester, 'taxesLine-cantonalIncome'), "Taux total 10.0750 % · 7'858.50");
    expect(text(tester, 'taxesLine-communalIncome'), "Taux total 5.1350 % · 4'005.30");
    expect(text(tester, 'taxesLine-cantonalWealth'), 'Taux total 0.3875 % · 775.00');
    expect(text(tester, 'taxesLine-communalWealth'), 'Taux total 0.1975 % · 395.00');
    expect(text(tester, 'taxesTotal'), "15'033.80");
    expect(text(tester, 'taxesShareOfGross'), '15.66 %');
    expect(text(tester, 'taxesShareOfNet'), '17.93 %');
    expect(text(tester, 'taxesPaid'), "12'000.00");
    expect(find.text('Reste à payer'), findsOneWidget);
    expect(text(tester, 'taxesGap'), "3'033.80");

    await tester.ensureVisible(find.byKey(const Key('taxesSave')));
    await tester.tap(find.byKey(const Key('taxesSave')));
    await settle(tester);
    expect(find.text('Année fiscale enregistrée.'), findsOneWidget);
    final year = (await tester.runAsync(services.ledger.load))!.taxYear(2026);
    expect((year.total, year.record!.marginalRate, year.record!.taxableWealth), (1503380, 3150, 20000000));
    await tester.ensureVisible(find.byKey(const ValueKey('taxesSummary-2026')));
    expect(text(tester, 'taxesSummary-2026'), contains("Total 15'033.80 · brut 15.66 % · net 17.93 % · TMI 31.50 %"));

    // A rate above 100 % is refused with its reason.
    await type('taxesRate-federalIncome', '101');
    await tester.ensureVisible(find.byKey(const Key('taxesSave')));
    await tester.tap(find.byKey(const Key('taxesSave')));
    await settle(tester);
    expect(find.text('Un taux de base va de 0 à 100 %, avec quatre décimales au plus.'), findsOneWidget);
  });
}
