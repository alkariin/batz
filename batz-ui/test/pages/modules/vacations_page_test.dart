import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/vacations.dart';
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

  Future<void> entry(
    WidgetTester tester,
    String id,
    int cents,
    CalendarDate date, {
    CalendarDate? start,
    CalendarDate? end,
    String? refunds,
  }) => write(
    tester,
    (l) => l.recordEntry(
      id,
      '$id-line',
      EntryDraft(
        accountId: 'cash',
        date: date,
        cents: cents,
        direction: refunds == null ? Direction.outflow : Direction.inflow,
        categoryId: refunds == null ? 'trips' : null,
        periodStart: start,
        periodEnd: end,
        refundedLineId: refunds,
      ),
    ),
  );

  testWidgets('the trips of the example by year; a trip given its place and days, its amount replaced then '
      'restored; a manual line added', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = (await tester.runAsync(() => testServices(today: () => d(2026, 11, 21))))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await write(tester, (l) => l.createAccount('cash', const AccountDraft(name: 'Compte', type: AccountType.cash)));
    await write(tester, (l) => l.createTree(2026));
    await write(
      tester,
      (l) =>
          l.addCategory('trips', year: 2026, name: 'Vacances', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
    await entry(tester, 'flight', 64000, d(2026, 3, 12), start: d(2026, 7, 10), end: d(2026, 7, 24));
    await entry(tester, 'hotel', 120000, d(2026, 7, 11));
    await entry(tester, 'meal', 8500, d(2026, 7, 20));
    await entry(tester, 'back', 10000, d(2026, 8, 5), refunds: 'hotel-line');
    await entry(tester, 'later', 30000, d(2026, 8, 9));
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('moreVacations')));
    await settle(tester);

    expect(text(tester, 'vacationsYear-2026'), "2026 · 2'125.00");
    expect(text(tester, 'tripAmount-line-flight-line'), "1'825.00");
    expect(text(tester, 'tripAmount-line-later-line'), '300.00');

    await tester.tap(find.byKey(const ValueKey('trip-line-flight-line')));
    await settle(tester);
    expect(find.byKey(const ValueKey('tripLine-back-line')), findsOneWidget, reason: 'the refund follows its expense');
    expect(text(tester, 'tripAutomaticAmount'), "Automatique : 1'825.00");
    await tester.enterText(find.byKey(const Key('tripPlace')), 'Lisbonne');
    await tester.enterText(find.byKey(const Key('tripDays')), '14');
    await tester.tap(find.byKey(const Key('tripSave')));
    await settle(tester);
    expect(find.text('10.07.2026 · 14 jours · 130.36 par jour'), findsOneWidget);
    expect(find.text('Lisbonne'), findsOneWidget);

    // The amount replaced, then restored.
    await tester.tap(find.byKey(const ValueKey('trip-line-flight-line')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('tripAmount')), "2'000");
    await tester.pump();
    await tester.tap(find.byKey(const Key('tripSave')));
    await settle(tester);
    expect(text(tester, 'tripAmount-line-flight-line'), "2'000.00");
    await tester.tap(find.byKey(const ValueKey('trip-line-flight-line')));
    await settle(tester);
    expect(text(tester, 'tripAutomaticAmount'), "Automatique : 1'825.00");
    await tester.tap(find.byKey(const ValueKey('tripRestoreAmount')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tripSave')));
    await settle(tester);
    expect(text(tester, 'tripAmount-line-flight-line'), "1'825.00");

    // A manual line: date and amount required.
    await tester.tap(find.byKey(const Key('vacationsAddManual')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('tripPlace')), 'Camping');
    await tester.tap(find.byKey(const Key('tripSave')));
    await settle(tester);
    expect(find.text('Une ligne manuelle a une date.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('tripDate')), '01.08.2025');
    await tester.enterText(find.byKey(const Key('tripAmount')), '450');
    await tester.enterText(find.byKey(const Key('tripDays')), '6');
    await tester.tap(find.byKey(const Key('tripSave')));
    await settle(tester);
    expect(text(tester, 'vacationsYear-2025'), '2025 · 450.00');
    final trips = (await tester.runAsync(services.ledger.load))!.vacations.trips;
    expect(trips.map((t) => (t.place, t.amount)), [('', 30000), ('Lisbonne', 182500), ('Camping', 45000)]);
  });
}
