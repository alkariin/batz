import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/pages/ledger_cubit.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../accounts/accounts_page_test.dart' show createAccount, openAccounts, pumpApp, settle;
import '../categories/categories_page_test.dart' show addChild;

Finder tab(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String label, String item) async {
  await tapVisible(tester, find.widgetWithText(DropdownButtonFormField<String>, label));
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

Future<void> newTransaction(WidgetTester tester, String kind) async {
  await tester.tap(tab('Transactions'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Nouvelle transaction'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(kind));
  await tester.pumpAndSettle();
}

/// Writes through the ledger of the running app, as a page would.
Future<void> seed(WidgetTester tester, AppServices services, Modification Function(Ledger l) build) async {
  await tester.runAsync(() async => services.ledger.write(build(await services.ledger.load())));
}

void main() {
  testWidgets('main path: create an account, a category, an expense, and find it in the list', (tester) async {
    await pumpApp(tester);

    await openAccounts(tester);
    await createAccount(tester, 'Espèces', type: 'Espèces');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('moreCategories')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining("Créer l'arbre"));
    await settle(tester);
    await addChild(tester, 'Dépenses', 'Nourriture');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await newTransaction(tester, 'Dépense ou revenu');
    await tester.enterText(find.byKey(const Key('amount')), '45.90');
    await choose(tester, 'Catégorie', 'Nourriture · dépenses');
    await tester.enterText(find.byKey(const Key('description')), 'Migros');
    await tapVisible(tester, find.byKey(const Key('save')));
    await settle(tester);

    expect(find.widgetWithText(AppBar, 'Transactions'), findsOneWidget);
    final tile = find.widgetWithText(ListTile, 'Migros');
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('-45.90')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.textContaining('Dépense · Nourriture · Espèces')), findsOneWidget);
  });

  testWidgets('a payment spread over two years shows its shares per month and its total per year', (tester) async {
    final services = await pumpApp(tester);
    await seed(
      tester,
      services,
      (l) => l.createAccount('cash', const AccountDraft(name: 'Espèces', type: AccountType.cash)),
    );
    await seed(tester, services, (l) => l.createTree(2026));
    await seed(
      tester,
      services,
      (l) =>
          l.addCategory('ins', year: 2026, name: 'Assurances', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
    await tester.runAsync(() => tester.element(find.byType(NavigationBar)).read<LedgerCubit>().load());
    await tester.pumpAndSettle();

    await newTransaction(tester, 'Dépense ou revenu');
    await tester.enterText(find.byKey(const Key('amount')), "2'100");
    await tester.enterText(find.byKey(const Key('date')), '25.08.2026');
    await tester.pumpAndSettle();
    await choose(tester, 'Catégorie', 'Assurances · dépenses');
    await tapVisible(tester, find.byKey(const Key('customPeriod')));
    await tester.enterText(find.byKey(const Key('periodStart')), '01.09.2026');
    await tester.enterText(find.byKey(const Key('periodEnd')), '31.08.2027');
    await tapVisible(tester, find.byKey(const Key('save')));
    await settle(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Assurances'));
    await tester.pumpAndSettle();
    expect(find.text('01.09.2026 – 31.08.2027'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('yearTotal-2026')), matching: find.text('-700.00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(const ValueKey('yearTotal-2027')), matching: find.text("-1'400.00")),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.byKey(const ValueKey('share-2027-08')), 100);
    expect(
      find.descendant(of: find.byKey(const ValueKey('share-2027-08')), matching: find.text('-175.00')),
      findsOneWidget,
    );
  });

  testWidgets('a transfer, then its correction and deletion', (tester) async {
    final services = await pumpApp(tester);
    await seed(
      tester,
      services,
      (l) => l.createAccount('cash', const AccountDraft(name: 'Espèces', type: AccountType.cash)),
    );
    await seed(
      tester,
      services,
      (l) => l.createAccount('ubs', const AccountDraft(name: 'UBS', type: AccountType.privateAccount)),
    );
    await tester.runAsync(() => tester.element(find.byType(NavigationBar)).read<LedgerCubit>().load());

    await newTransaction(tester, 'Transfert');
    await tester.enterText(find.byKey(const Key('amount')), '300');
    await choose(tester, 'Compte de départ', 'UBS');
    await choose(tester, "Compte d'arrivée", 'UBS');
    await tapVisible(tester, find.byKey(const Key('save')));
    await settle(tester);
    expect(find.text('Choisissez deux comptes différents.'), findsOneWidget);

    await choose(tester, "Compte d'arrivée", 'Espèces');
    await tapVisible(tester, find.byKey(const Key('save')));
    await settle(tester);
    final tile = find.widgetWithText(ListTile, 'Transfert');
    expect(find.descendant(of: tile, matching: find.text('-300.00')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.textContaining('UBS → Espèces')), findsOneWidget);

    // Seen from the arrival account, the money comes in.
    await tester.tap(find.byKey(const Key('filterAccount')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Espèces').last);
    await tester.pumpAndSettle();
    expect(find.descendant(of: tile, matching: find.text('300.00')), findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount')), '250');
    await tapVisible(tester, find.byKey(const Key('save')));
    await settle(tester);
    expect(find.text('-250.00'), findsWidgets);

    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await settle(tester);
    expect(find.text('Aucune transaction.'), findsOneWidget);
  });

  testWidgets('an expense split between two categories, each with its amount and period, then brought back to one', (
    tester,
  ) async {
    final services = await pumpApp(tester);
    await seed(
      tester,
      services,
      (l) => l.createAccount('cash', const AccountDraft(name: 'Espèces', type: AccountType.cash)),
    );
    await seed(tester, services, (l) => l.createTree(2026));
    final expenses = defaultGroupId(2026, CategoryNature.expense);
    await seed(tester, services, (l) => l.addCategory('food', year: 2026, name: 'Nourriture', parentId: expenses));
    await seed(tester, services, (l) => l.addCategory('home', year: 2026, name: 'Ménage', parentId: expenses));
    await tester.runAsync(() => tester.element(find.byType(NavigationBar)).read<LedgerCubit>().load());
    await tester.pumpAndSettle();
    Future<Ledger> ledger() async => (await tester.runAsync(services.ledger.load))!;

    await newTransaction(tester, 'Dépense ou revenu');
    await tester.enterText(find.byKey(const Key('amount')), '120');
    await tester.enterText(find.byKey(const Key('date')), '10.05.2026');
    await tester.pumpAndSettle();
    await choose(tester, 'Catégorie', 'Nourriture · dépenses');
    await tester.enterText(find.byKey(const Key('description')), 'Migros');
    await tapVisible(tester, find.byKey(const Key('split')));
    expect(find.byKey(const Key('customPeriod')), findsNothing, reason: 'each line has its period');
    await tapVisible(tester, find.byKey(const Key('splitCategory-1')));
    await tester.tap(find.text('Ménage · dépenses').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('splitAmount-1')), '20');
    await tester.enterText(find.byKey(const Key('splitEnd-1')), '30.06.2026');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('splitRest'))).data, '100.00');

    // Lines over the amount are refused.
    await tester.enterText(find.byKey(const Key('splitAmount-1')), '130');
    await tapVisible(tester, find.byKey(const Key('save')));
    expect(find.text('Les autres lignes dépassent le montant de la transaction.'), findsOneWidget);
    // The message would cover the button.
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('splitAmount-1')), '20');
    await tapVisible(tester, find.byKey(const Key('save')));
    await settle(tester);

    final tile = find.widgetWithText(ListTile, 'Migros');
    expect(find.descendant(of: tile, matching: find.textContaining('Nourriture + Ménage')), findsOneWidget);
    var t = (await ledger()).transactions.values.single;
    expect([for (final line in t.lines) (line.categoryId, line.amount)], [('food', -10000), ('home', -2000)]);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('Ventilation'), findsOneWidget);
    expect(find.text('10.05.2026 – 30.06.2026'), findsOneWidget, reason: 'the period of the second line');
    expect(
      find.descendant(of: find.byKey(const ValueKey('yearTotal-2026')), matching: find.text('-120.00')),
      findsOneWidget,
    );

    // Brought back to one category: the main line takes the whole amount.
    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('splitRemove-1')));
    expect(find.byKey(const Key('splitRest')), findsNothing);
    await tapVisible(tester, find.byKey(const Key('save')));
    await settle(tester);
    t = (await ledger()).transactions.values.single;
    expect([for (final line in t.lines) (line.categoryId, line.amount)], [('food', -12000)]);
  });
}
