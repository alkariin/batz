import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/electricity.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show settle;

void main() {
  late AppServices services;
  CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  Future<void> write(WidgetTester tester, Modification Function(Ledger l) build) =>
      tester.runAsync(() async => services.ledger.write(build(await services.ledger.load())));

  testWidgets('the invoices of the example: the kWh entered from the screen give the figures of each year', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = (await tester.runAsync(() => testServices(today: () => d(2026, 11, 21))))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await write(tester, (l) => l.createAccount('cash', const AccountDraft(name: 'Compte', type: AccountType.cash)));
    await write(tester, (l) => l.createTree(2026));
    await write(
      tester,
      (l) => l.addCategory(
        'power',
        year: 2026,
        name: 'Électricité',
        parentId: defaultGroupId(2026, CategoryNature.expense),
      ),
    );
    for (final (id, cents, date, start, end) in [
      ('i1', 48000, d(2026, 5, 15), d(2026, 1, 1), d(2026, 4, 30)),
      ('i2', 54000, d(2026, 11, 15), d(2026, 5, 1), d(2026, 10, 31)),
      ('i3', 30000, d(2027, 1, 20), d(2026, 11, 1), d(2027, 1, 31)),
    ]) {
      await write(
        tester,
        (l) => l.recordEntry(
          id,
          '$id-l',
          EntryDraft(
            accountId: 'cash',
            date: date,
            cents: cents,
            direction: Direction.outflow,
            categoryId: l.treeOrPreview(date.year).named('Électricité')!.id,
            periodStart: start,
            periodEnd: end,
          ),
        ),
      );
    }
    await write(tester, (l) => l.setElectricity('i1-l', 1900000));
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('moreElectricity')));
    await settle(tester);
    expect(text(tester, 'electricity-2026-price'), "1'220.00");
    expect(text(tester, 'electricityMissing-2026'), '2 lignes sans kWh : le prix par kWh est surestimé.');

    await tester.tap(find.byKey(const ValueKey('electricityYear-2026')));
    await settle(tester);
    for (final (line, kwh) in [('i2-l', "2'000"), ('i3-l', '1200')]) {
      await tester.tap(find.byKey(ValueKey('electricityLine-$line')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('electricityKwh')), kwh);
      await tester.tap(find.byKey(const Key('electricitySave')));
      await settle(tester);
    }
    expect(text(tester, 'electricityKwh-i3-l'), "1'200 kWh");
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(
      [
        for (final key in ['price', 'kwh', 'days', 'perDay', 'perKwh', 'kwhPerDay'])
          text(tester, 'electricity-2026-$key'),
      ],
      ["1'220.00", "4'700", '365', '3.34', '0.2596', '12.88'],
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('electricity-2027-kwhPerDay')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      [
        for (final key in ['price', 'kwh', 'days', 'perDay', 'perKwh', 'kwhPerDay'])
          text(tester, 'electricity-2027-$key'),
      ],
      ['100.00', '400', '31', '3.23', '0.2500', '12.90'],
    );
    expect(find.byKey(const ValueKey('electricityMissing-2026')), findsNothing);
  });
}
