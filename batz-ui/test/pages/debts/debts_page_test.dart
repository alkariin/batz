import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/debt.dart';
import 'package:batz/pages/debts/debts_page.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show settle;

void main() {
  late AppServices services;
  final today = CalendarDate(2026, 11, 21);

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = (await tester.runAsync(() => testServices(today: () => today)))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await tester.runAsync(() async {
      final ledger = await services.ledger.load();
      await services.ledger.write(
        ledger.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)),
      );
    });
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Fortune')));
    await settle(tester);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await settle(tester);
  }

  Future<List<Debt>> debts(WidgetTester tester) async =>
      (await tester.runAsync(() async => (await services.ledger.load()).sortedDebts))!;

  testWidgets('a debt entered, split, then one part checked: the line « Dettes » of the wealth follows', (
    tester,
  ) async {
    await start(tester);
    expect(text(tester, 'wealthDebts'), '0.00');
    await tester.tap(find.byKey(const Key('wealthDebtsLine')));
    await settle(tester);
    expect(find.byType(DebtsPage), findsOneWidget);

    // Entered: 200 at 50 %, the total computed as it is typed.
    await tester.tap(find.byKey(const Key('newDebt')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('debtPerson')), 'Alex Modèle');
    await tester.enterText(find.byKey(const Key('debtAmount')), '200');
    await tester.pump();
    expect(text(tester, 'debtTotal'), 'Total : 200.00', reason: '100 % by default');
    await tester.enterText(find.byKey(const Key('debtPercent')), '50');
    await tester.pump();
    expect(text(tester, 'debtTotal'), 'Total : 100.00');
    await tester.enterText(find.byKey(const Key('debtDescription')), 'Restaurant');
    await tester.enterText(find.byKey(const Key('debtEventDate')), '14.03.2026');
    await tester.enterText(find.byKey(const Key('debtInvoiceDate')), '15.03.2026');
    await tester.ensureVisible(find.byKey(const Key('saveDebt')));
    await tester.tap(find.byKey(const Key('saveDebt')));
    await settle(tester);
    var list = await debts(tester);
    final id = list.single.id;
    expect(
      (list.single.amount, list.single.basisPoints, list.single.eventDate, list.single.invoiceDate),
      (20000, 5000, CalendarDate(2026, 3, 14), CalendarDate(2026, 3, 15)),
    );
    expect(list.single.enteredOn, today);
    expect(text(tester, 'debtTotal-$id'), '+100.00');
    expect(
      (text(tester, 'debtsOwedToMe'), text(tester, 'debtsIOwe'), text(tester, 'debtsNet')),
      ('100.00', '0.00', '100.00'),
    );
    await back(tester);
    expect(text(tester, 'wealthDebts'), '100.00');
    expect(text(tester, 'wealthNet'), '100.00');

    // Split: 40 for the first part, the rest on a second line.
    await tester.tap(find.byKey(const Key('wealthDebtsLine')));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('debtMenu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scinder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('debtSplitAmount')), '100');
    await tester.tap(find.byKey(const Key('debtSplitConfirm')));
    await tester.pumpAndSettle();
    expect(
      find.text('La première part doit être supérieure à zéro et inférieure au total de la dette.'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('debtSplitAmount')), '40');
    await tester.tap(find.byKey(const Key('debtSplitConfirm')));
    await settle(tester);
    expect(find.text('Dette scindée en 40.00 et 60.00.'), findsOneWidget);
    list = await debts(tester);
    expect(list.map((d) => d.total).toList()..sort(), [4000, 6000]);
    expect(list.every((d) => d.basisPoints == 10000 && d.eventDate == CalendarDate(2026, 3, 14)), isTrue);
    final second = list.firstWhere((d) => d.id != id).id;
    expect(text(tester, 'debtTotal-$second'), '+60.00');
    expect(text(tester, 'debtsNet'), '100.00');

    // The part of 60 checked: today is proposed as the date of receipt.
    await tester.tap(find.byKey(ValueKey('debtCheck-$second')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('debtCheckDate'))).controller!.text, '21.11.2026');
    await tester.tap(find.byKey(const Key('debtCheckConfirm')));
    await settle(tester);
    list = await debts(tester);
    final checked = list.firstWhere((d) => d.id == second);
    expect((checked.repaid, checked.receivedDate, checked.checkedOn), (true, today, today));
    expect(text(tester, 'debtsNet'), '40.00');
    await back(tester);
    expect(text(tester, 'wealthDebts'), '40.00');

    // Unchecked, it counts again; the other part deleted.
    await tester.tap(find.byKey(const Key('wealthDebtsLine')));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('debtCheck-$second')));
    await settle(tester);
    expect(text(tester, 'debtsNet'), '100.00');
    await tester.tap(find.byKey(ValueKey('debtMenu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await settle(tester);
    expect((await debts(tester)).map((d) => d.id), [second]);
    await back(tester);
    expect(text(tester, 'wealthDebts'), '60.00');
  });

  testWidgets('the form refuses with their reason a debt without person, and a receipt before the event; « je dois » '
      'takes from the wealth', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(const Key('wealthDebtsLine')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('newDebt')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('debtAmount')), '80');
    await tester.ensureVisible(find.byKey(const Key('saveDebt')));
    await tester.tap(find.byKey(const Key('saveDebt')));
    await settle(tester);
    expect(find.text('Indiquez la personne.'), findsOneWidget);

    await tester.tap(find.text('Je dois'));
    await tester.enterText(find.byKey(const Key('debtPerson')), 'Camille Exemple');
    await tester.enterText(find.byKey(const Key('debtEventDate')), '10.10.2026');
    await tester.enterText(find.byKey(const Key('debtReceivedDate')), '09.10.2026');
    await tester.ensureVisible(find.byKey(const Key('saveDebt')));
    await tester.tap(find.byKey(const Key('saveDebt')));
    await settle(tester);
    expect(find.text("La date de réception ne peut pas précéder la date de l'événement."), findsOneWidget);
    await tester.enterText(find.byKey(const Key('debtReceivedDate')), '');
    await tester.ensureVisible(find.byKey(const Key('saveDebt')));
    await tester.tap(find.byKey(const Key('saveDebt')));
    await settle(tester);
    expect(text(tester, 'debtsIOwe'), '80.00');
    expect(text(tester, 'debtsNet'), '-80.00');
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(text(tester, 'wealthDebts'), '-80.00');
  });
}
