import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/pages/modules/flow_page.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/flow_example.dart';
import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show settle;

void main() {
  late AppServices services;

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  Future<void> openFlow(
    WidgetTester tester,
    Size size, {
    Brightness brightness = Brightness.light,
    bool sheet = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    services = (await tester.runAsync(() => testServices(today: () => CalendarDate(2026, 11, 21))))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await tester.runAsync(
      () => flowExample((build) async {
        await services.ledger.write(build(await services.ledger.load()));
        return services.ledger.load();
      }, sheet: sheet),
    );
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
    final nav = size.width < 600 ? find.byType(NavigationBar) : find.byType(NavigationRail);
    await tester.tap(find.descendant(of: nav, matching: find.text('Année')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('yearPick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yearFlow')));
    await settle(tester);
    expect(find.byType(FlowPage), findsOneWidget);
  }

  Future<void> expectExample(WidgetTester tester) async {
    expect(find.byKey(const Key('flowChart')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('flowTotal-right')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(text(tester, 'flowTotal-left'), "Total : 96'144.00");
    expect(text(tester, 'flowTotal-right'), "Total : 96'144.00");
    expect(text(tester, 'flowAmount-left-gross'), "96'000.00");
    expect(text(tester, 'flowAmount-right-taxes'), "15'000.00");
    expect(text(tester, 'flowAmount-right-savings'), "21'000.00");
    expect(find.text('Obligations hors Impôts'), findsOneWidget);
    expect(find.text('Revenus hors Salaire'), findsOneWidget);
    // The subcategories, under their group in the list.
    expect(text(tester, 'flowAmount-right-category-rent'), "24'000.00");
    expect(text(tester, 'flowAmount-right-category-insurance'), "6'000.00");
    final group = tester.getTopLeft(find.byKey(const ValueKey('flowNode-right-group-duties')));
    final child = tester.getTopLeft(find.byKey(const ValueKey('flowNode-right-category-insurance')));
    expect((child.dy > group.dy, child.dx), (true, group.dx), reason: 'right under its group, indented inside');
  }

  testWidgets('on a phone, from « Année »: the diagram of the example starts from the gross, in both views', (
    tester,
  ) async {
    await openFlow(tester, const Size(400, 900));
    expect(find.text('Le diagramme part du salaire brut de la fiche 2026.'), findsOneWidget);
    expect(find.byKey(const Key('flowScroll')), findsOneWidget, reason: 'three columns scroll sideways on a phone');
    await expectExample(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('flowKind')), -300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Trésorerie'));
    await settle(tester);
    await expectExample(tester);
  });

  testWidgets('on a desktop, in the dark theme, without sheet: from the net, 84\'000.00 on each side', (tester) async {
    await openFlow(tester, const Size(1280, 900), brightness: Brightness.dark, sheet: false);
    expect(find.text('Le diagramme part du salaire net : pas de fiche salaire pour 2026.'), findsOneWidget);
    expect(text(tester, 'flowTotal-left'), "Total : 84'000.00");
    expect(text(tester, 'flowAmount-left-salary'), "83'856.00");
    expect(find.byKey(const Key('flowGrossGap')), findsNothing);
    expect(find.byKey(const Key('flowScroll')), findsNothing, reason: 'room enough on a desktop');
  });
}
