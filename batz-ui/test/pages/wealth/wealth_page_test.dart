import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/balance.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/pages/validation/validation_page.dart';
import 'package:batz/pages/wealth/account_page.dart';
import 'package:batz/pages/year/year_page.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/reference_example.dart';
import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show settle;

void main() {
  late AppServices services;

  Future<Ledger> write(WidgetTester tester, Modification Function(Ledger l) build) async =>
      (await tester.runAsync(() async {
        await services.ledger.write(build(await services.ledger.load()));
        return services.ledger.load();
      }))!;

  Future<void> start(WidgetTester tester, CalendarDate today, {Size size = const Size(400, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = (await tester.runAsync(() => testServices(today: () => today)))!;
    addTearDown(() => tester.runAsync(services.database.close));
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
  }

  Future<void> openWealth(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Fortune')));
    await settle(tester);
  }

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('the « Fortune » screen shows the accounts, the curve and the table of the reference example', (
    tester,
  ) async {
    final today = CalendarDate(2027, 1, 15);
    await start(tester, today);
    await tester.runAsync(
      () => referenceExample((build) async {
        await services.ledger.write(build(await services.ledger.load()));
        return services.ledger.load();
      }, today: today),
    );
    await pumpApp(tester);
    await openWealth(tester);

    expect(text(tester, 'wealthNet'), "27'359.00");
    expect(text(tester, 'wealthSinceYearStart'), '0.00', reason: 'nothing moved since 31.12.2026');
    expect(text(tester, 'wealthBalance-private'), "3'909.00");
    expect(text(tester, 'wealthBalance-savings'), "16'250.00");
    expect(text(tester, 'wealthBalance-pillar'), "7'100.00");
    expect(text(tester, 'wealthType-pillar3'), "7'100.00");
    expect(text(tester, 'wealthDebts'), '100.00');
    expect(
      find.text('Relevé au 31.12.2026'),
      findsOneWidget,
      reason: 'the bank gives the balance of the private account',
    );

    // The curve: the current month first, then the month touched.
    await scrollTo(tester, find.byKey(const Key('wealthCurve')));
    expect(text(tester, 'wealthCurvePoint'), "01.2027 : 27'359.00");
    final curve = tester.getRect(find.byKey(const Key('wealthCurve')));
    await tester.tapAt(curve.centerLeft + const Offset(1, 0));
    await tester.pumpAndSettle();
    expect(text(tester, 'wealthCurvePoint'), "12.2025 : 15'000.00");
    await tester.tapAt(curve.centerRight - const Offset(1, 0));
    await tester.pumpAndSettle();
    expect(text(tester, 'wealthCurvePoint'), "01.2027 : 27'359.00");

    // The table of 2026, chosen among the years.
    await scrollTo(tester, find.byKey(const Key('wealthYear')));
    await tester.tap(find.byKey(const Key('wealthYear')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026').last);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('explain-change')));
    expect(
      {
        for (final key in [
          'economic',
          'offsets',
          'cash',
          'variations',
          'added',
          'debts',
          'unclassified',
          'outside',
          'change',
        ])
          key: text(tester, 'explain-$key'),
      },
      {
        'economic': "13'400.00",
        'offsets': "-1'400.00",
        'cash': "12'000.00",
        'variations': '+250.00',
        'added': "+7'100.00",
        'debts': '+100.00',
        'unclassified': '-35.00',
        'outside': "-7'056.00",
        'change': "+12'359.00",
      },
    );
    // The lines by account unfold.
    expect(find.byKey(const ValueKey('explainDetail-variations-savings')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('explainLine-variations')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('explainDetail-variations-savings')),
        matching: find.text('Épargne'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('explainLine-outside')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('explainDetail-outside-pillar')), findsOneWidget);

    // « Non classé » leads to the validation, the results to « Année ».
    await tester.tap(find.byKey(const ValueKey('explainLine-unclassified')));
    await settle(tester);
    expect(find.byType(ValidationPage), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await scrollTo(tester, find.byKey(const ValueKey('explainLine-cash')));
    await tester.tap(find.byKey(const ValueKey('explainLine-cash')));
    await settle(tester);
    expect(tester.widget<YearPage>(find.byType(YearPage)).initialYear, 2026);
  });

  testWidgets('on a wide screen the table of 2025, before any tree, shows only the balances that enter the wealth', (
    tester,
  ) async {
    final today = CalendarDate(2027, 1, 15);
    await start(tester, today, size: const Size(1280, 900));
    await tester.runAsync(
      () => referenceExample((build) async {
        await services.ledger.write(build(await services.ledger.load()));
        return services.ledger.load();
      }, today: today),
    );
    await pumpApp(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Fortune')));
    await settle(tester);
    await scrollTo(tester, find.byKey(const Key('wealthYear')));
    await tester.tap(find.byKey(const Key('wealthYear')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025').last);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const ValueKey('explain-change')));
    expect(find.byKey(const Key('wealthNoTree')), findsOneWidget);
    expect(text(tester, 'explain-added'), "+15'000.00");
    expect(text(tester, 'explain-change'), "+15'000.00");
    expect(find.byKey(const ValueKey('explain-outside')), findsNothing, reason: 'shown only when not zero');
  });

  testWidgets('declaring a balance shows its value variation, which the history keeps', (tester) async {
    final today = CalendarDate(2026, 11, 21);
    await start(tester, today);
    await write(
      tester,
      (l) => l.createAccount('private', const AccountDraft(name: 'UBS', type: AccountType.privateAccount)),
    );
    await write(
      tester,
      (l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)),
    );
    await write(tester, (l) => l.declareBalance('savings', CalendarDate(2025, 12, 31), 1000000, today: today));
    await write(
      tester,
      (l) => l.recordTransfer(
        'in',
        TransferDraft(fromAccountId: 'private', toAccountId: 'savings', date: CalendarDate(2026, 3, 15), cents: 50000),
      ),
    );
    await pumpApp(tester);
    await openWealth(tester);
    expect(text(tester, 'wealthBalance-savings'), "10'500.00");
    await tester.tap(find.byKey(const ValueKey('wealthAccount-savings')));
    await settle(tester);
    expect(find.byType(AccountPage), findsOneWidget);
    expect(text(tester, 'accountBalance'), "10'500.00");

    await tester.tap(find.byKey(const Key('declareBalance')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(const Key('balanceDate'))).controller!.text,
      '21.11.2026',
      reason: 'today by default',
    );
    await tester.enterText(find.byKey(const Key('balanceAmount')), "10'800");
    await tester.enterText(find.byKey(const Key('balanceDate')), '30.06.2026');
    await tester.tap(find.byKey(const Key('saveBalance')));
    await settle(tester);
    expect(find.text('Variation de valeur : +300.00'), findsOneWidget);
    expect(text(tester, 'accountBalance'), "10'800.00");
    final id = balanceId('savings', CalendarDate(2026, 6, 30));
    expect(text(tester, 'balanceVariation-$id'), 'Variation +300.00');

    // A date to come is refused, with its reason.
    await tester.tap(find.byKey(const Key('declareBalance')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('balanceAmount')), '1');
    await tester.enterText(find.byKey(const Key('balanceDate')), '22.11.2026');
    await tester.tap(find.byKey(const Key('saveBalance')));
    await settle(tester);
    expect(find.text('Un solde ne se déclare pas pour une date future.'), findsOneWidget);

    // Modified then deleted from the history.
    await tester.tap(find.byKey(ValueKey('balanceStep-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('editBalance-$id')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('balanceAmount')), "10'450");
    await tester.tap(find.byKey(const Key('saveBalance')));
    await settle(tester);
    expect(find.text('Variation de valeur : -50.00'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('balanceStep-$id')));
    await tester.pumpAndSettle();
    if (find.byKey(ValueKey('editBalance-$id')).evaluate().isEmpty) {
      await tester.tap(find.byKey(ValueKey('balanceStep-$id')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(ValueKey('editBalance-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteBalance')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await settle(tester);
    expect(text(tester, 'accountBalance'), "10'500.00");
    expect(find.byKey(ValueKey('balanceStep-$id')), findsNothing);
  });

  testWidgets('a balance declared more than six months ago is a task of the home screen, which leads to its account; '
      'a new balance clears it; the net wealth joins the key figures', (tester) async {
    final today = CalendarDate(2026, 11, 21);
    await start(tester, today);
    await write(
      tester,
      (l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)),
    );
    await write(
      tester,
      (l) => l.createAccount('pillar', const AccountDraft(name: '3e pilier', type: AccountType.pillar3)),
    );
    await write(tester, (l) => l.declareBalance('savings', CalendarDate(2026, 5, 20), 500000, today: today));
    await write(tester, (l) => l.declareBalance('pillar', CalendarDate(2026, 5, 21), 700000, today: today));
    await pumpApp(tester);

    expect(find.byKey(const ValueKey('taskOldBalance-savings')), findsOneWidget);
    expect(find.text('Solde de « Épargne » à mettre à jour'), findsOneWidget);
    expect(find.byKey(const ValueKey('taskOldBalance-pillar')), findsNothing, reason: 'six months to the day');
    expect(text(tester, 'keyWealth'), "12'000.00");

    await tester.tap(find.byKey(const ValueKey('taskOldBalance-savings')));
    await settle(tester);
    expect(find.byKey(const Key('accountOld')), findsOneWidget);
    await tester.tap(find.byKey(const Key('declareBalance')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('balanceAmount')), "5'100");
    await tester.tap(find.byKey(const Key('saveBalance')));
    await settle(tester);
    expect(find.text('Variation de valeur : +100.00'), findsOneWidget);
    expect(find.byKey(const Key('accountOld')), findsNothing);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.byKey(const ValueKey('taskOldBalance-savings')), findsNothing);
    expect(text(tester, 'keyWealth'), "12'100.00");

    await tester.tap(find.byKey(const Key('keyWealthOpen')));
    await settle(tester);
    expect(text(tester, 'wealthNet'), "12'100.00");
    expect(find.byKey(const ValueKey('wealthOld-pillar')), findsNothing);
  });
}
