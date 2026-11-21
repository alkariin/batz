import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/pages/transactions/transaction_detail_page.dart';
import 'package:batz/pages/year/composition_page.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show settle;

void main() {
  // The current year, so that the home screen shows its key figures.
  final year = CalendarDate.today().year;
  late AppServices services;

  Future<void> write(WidgetTester tester, Modification Function(Ledger l) build) =>
      tester.runAsync(() async => services.ledger.write(build(await services.ledger.load())));

  /// Cash; the tree of the year with « Loyer » and « Salaire »; a salary in
  /// January; a rent of 2'100 paid on 1.9 for 1.9 – 31.8 of the next year.
  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = (await tester.runAsync(testServices))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await write(tester, (l) => l.createAccount('cash', const AccountDraft(name: 'Espèces', type: AccountType.cash)));
    await write(tester, (l) => l.createTree(year));
    await write(
      tester,
      (l) => l.addCategory('rent', year: year, name: 'Loyer', parentId: defaultGroupId(year, CategoryNature.expense)),
    );
    await write(
      tester,
      (l) =>
          l.addCategory('salary', year: year, name: 'Salaire', parentId: defaultGroupId(year, CategoryNature.income)),
    );
    await write(
      tester,
      (l) => l.recordEntry(
        'salary-1',
        'sl',
        EntryDraft(
          accountId: 'cash',
          date: CalendarDate(year, 1, 25),
          cents: 500000,
          direction: Direction.inflow,
          categoryId: 'salary',
        ),
      ),
    );
    await write(
      tester,
      (l) => l.recordEntry(
        'rent-1',
        'rl',
        EntryDraft(
          accountId: 'cash',
          date: CalendarDate(year, 9, 1),
          cents: 210000,
          direction: Direction.outflow,
          categoryId: 'rent',
          description: 'Loyer d\'avance',
          periodStart: CalendarDate(year, 9, 1),
          periodEnd: CalendarDate(year + 1, 8, 31),
        ),
      ),
    );
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
  }

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  Future<void> tapNav(WidgetTester tester, String label) async {
    final nav = find.byType(NavigationBar).evaluate().isEmpty
        ? find.byType(NavigationRail)
        : find.byType(NavigationBar);
    await tester.tap(find.descendant(of: nav, matching: find.text(label)));
    await settle(tester);
  }

  testWidgets('the toggle moves the amounts of a payment over two years; month by month; the transactions of a '
      'category; the view chosen is kept on the device', (tester) async {
    await open(tester, const Size(500, 1100));

    // Home: the key figures of the year, in the economic view.
    expect(text(tester, 'keyExpenses'), '700.00');
    expect(text(tester, 'keyIncome'), "5'000.00");
    expect(text(tester, 'keySavings'), "4'300.00");
    await tester.tap(find.byKey(const Key('keyFigures')));
    await settle(tester);

    // The screen opens on the economic view the first time: 700 of the
    // 2'100 concern this year, shown as a cost without a sign.
    expect(find.widgetWithText(AppBar, 'Année'), findsOneWidget);
    expect(text(tester, 'yearExpenses'), '700.00');
    expect(text(tester, 'yearAmount-rent'), '700.00');
    expect(text(tester, 'yearPaidForOtherYears'), "-1'400.00");
    await tester.tap(find.text('Trésorerie'));
    await settle(tester);
    expect(text(tester, 'yearExpenses'), "2'100.00");
    expect(text(tester, 'yearAmount-rent'), "2'100.00");
    expect(find.byKey(const ValueKey('yearPaidForOtherYears')), findsNothing, reason: 'offsets in the economic view');
    expect(text(tester, 'yearSavings'), "2'900.00");

    // Month by month: the line unfolds its twelve months.
    await tester.tap(find.byKey(const ValueKey('yearMonths-rent')));
    await settle(tester);
    final september = find.byKey(const ValueKey('yearMonth-rent-9'));
    expect(find.descendant(of: september, matching: find.text("2'100.00")), findsOneWidget);
    await tester.tap(find.text('Économique'));
    await settle(tester);
    expect(find.descendant(of: september, matching: find.text('175.00')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('yearMonth-rent-8')), matching: find.text('–')),
      findsOneWidget,
    );

    // A month opens its transactions, with the part counted; then the detail.
    await tester.tap(september);
    await settle(tester);
    expect(find.byType(CompositionPage), findsOneWidget);
    expect(text(tester, 'compositionTotal'), '175.00');
    expect(find.text("Loyer d'avance"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('composition-rent-1')));
    await settle(tester);
    expect(find.byType(TransactionDetailPage), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    // The whole category for the year, from its line.
    await tester.tap(find.byKey(const ValueKey('yearAmount-rent')));
    await settle(tester);
    expect(text(tester, 'compositionTotal'), '700.00');
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    // The next year shows the rest, with the tree its copy will give.
    await tester.tap(find.byKey(const Key('yearPick')));
    await settle(tester);
    await tester.tap(find.text('${year + 1}').last);
    await settle(tester);
    expect(text(tester, 'yearExpenses'), "1'400.00");
    expect(find.textContaining("n'a pas encore d'arbre"), findsOneWidget);

    // A group folds.
    final expenses = defaultGroupId(year, CategoryNature.expense);
    await tester.tap(find.byKey(const ValueKey('yearPick')));
    await settle(tester);
    await tester.tap(find.text('$year').last);
    await settle(tester);
    expect(find.byKey(const ValueKey('yearLine-rent')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('yearFold-$expenses')));
    await settle(tester);
    expect(find.byKey(const ValueKey('yearLine-rent')), findsNothing);

    // The last view chosen on this device comes back.
    await tapNav(tester, 'Accueil');
    await tapNav(tester, 'Année');
    expect(text(tester, 'yearExpenses'), '700.00');
    await tester.tap(find.text('Trésorerie'));
    await settle(tester);
    await tapNav(tester, 'Accueil');
    await tapNav(tester, 'Année');
    expect(text(tester, 'yearExpenses'), "2'100.00");
  });

  testWidgets('on a wide screen, twelve columns and the total; a cell opens the transactions of its month', (
    tester,
  ) async {
    await open(tester, const Size(1400, 1000));
    await tapNav(tester, 'Année');
    expect(find.text('sept.'), findsOneWidget);
    for (var m = 9; m <= 12; m++) {
      expect(
        find.descendant(of: find.byKey(ValueKey('yearMonth-rent-$m')), matching: find.text('175.00')),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: find.byKey(const ValueKey('yearAmount-rent')), matching: find.text('700.00')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('yearMonth-rent-10')));
    await settle(tester);
    expect(text(tester, 'compositionTotal'), '175.00');
  });
}
