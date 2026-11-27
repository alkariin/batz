import 'dart:async';

import 'package:batz/domain/journal/hlc.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/pages/categories/categories_page.dart';
import 'package:batz/pages/ledger_cubit.dart';
import 'package:batz/pages/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../accounts/accounts_page_test.dart' show pumpApp, settle, tapInList;

Future<void> openCategories(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
  await tester.pumpAndSettle();
  await tapInList(tester, find.byKey(const Key('moreCategories')));
  await tester.pumpAndSettle();
}

Future<void> menu(WidgetTester tester, String category, String action) async {
  await tester.tap(find.byKey(Key('categoryMenu-$category')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

Future<void> addChild(WidgetTester tester, String parent, String name) async {
  await menu(tester, parent, 'Ajouter une sous-catégorie');
  await tester.enterText(find.byKey(const Key('categoryName')), name);
  await tester.tap(find.text('Enregistrer'));
  await settle(tester);
}

void main() {
  testWidgets('categories: create the tree of the year, add, refuse a duplicate name, rename', (tester) async {
    await pumpApp(tester);
    await openCategories(tester);
    final year = (tester.widget(find.byType(CategoriesPage)) as CategoriesPage).initialYear ?? DateTime.now().year;

    expect(find.text("Pas encore d'arbre pour $year."), findsOneWidget);
    await tester.tap(find.text("Créer l'arbre $year"));
    await settle(tester);
    expect(find.text('Revenus'), findsOneWidget);
    expect(find.text('Dépenses'), findsOneWidget);

    await addChild(tester, 'Dépenses', 'Impôts');
    expect(find.text('Impôts'), findsOneWidget);

    await addChild(tester, 'Revenus', ' impots ');
    expect(find.textContaining('Ce nom est déjà utilisé'), findsOneWidget);
    expect(find.text(' impots '), findsNothing);

    await menu(tester, 'Impôts', 'Renommer');
    await tester.enterText(find.byKey(const Key('categoryName')), 'Impôts et taxes');
    await tester.tap(find.text('Enregistrer'));
    await settle(tester);
    expect(find.text('Impôts et taxes'), findsOneWidget);

    // The next year's tree can be created by hand, as a copy.
    await tester.tap(find.byKey(const Key('categoriesYear')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${year + 1}').last);
    await tester.pumpAndSettle();
    expect(find.textContaining("copié de l'arbre $year"), findsOneWidget);
    await tester.tap(find.text("Créer l'arbre ${year + 1}"));
    await settle(tester);
    expect(find.text('Impôts et taxes'), findsOneWidget);
  });

  testWidgets('categories detached by two concurrent moves are listed « À replacer » and can be moved back', (
    tester,
  ) async {
    final services = await pumpApp(tester);
    final year = DateTime.now().year;
    final expenses = defaultGroupId(year, CategoryNature.expense);
    await tester.runAsync(() async {
      var ledger = await services.ledger.load();
      await services.ledger.write(ledger.createTree(year));
      ledger = await services.ledger.load();
      await services.ledger.write(ledger.addCategory('housing', year: year, name: 'Logement', parentId: expenses));
      ledger = await services.ledger.load();
      await services.ledger.write(ledger.addCategory('rent', year: year, name: 'Loyer', parentId: 'housing'));
      ledger = await services.ledger.load();
      await services.ledger.write(ledger.addCategory('food', year: year, name: 'Nourriture', parentId: expenses));
      // Two other devices each moved one under the other.
      const other = 'eeeeeeee-0000-4000-8000-000000000000';
      final later = DateTime.now().millisecondsSinceEpoch + 1000;
      await services.journal.merge([
        JournalEntry(Hlc(later, 0, other), FieldChange('category', 'housing', 'parentId', 'food')),
        JournalEntry(Hlc(later, 1, other), FieldChange('category', 'food', 'parentId', 'housing')),
      ]);
    });
    unawaited(tester.element(find.byType(AppShell)).read<LedgerCubit>().load());
    await settle(tester);
    await openCategories(tester);

    expect(find.text('À replacer'), findsOneWidget);
    expect(find.byKey(const Key('detachedMove-Logement')), findsOneWidget);
    expect(find.byKey(const Key('detachedMove-Nourriture')), findsOneWidget);
    expect(find.text('Placée sous une de ses propres sous-catégories'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('detached-rent')), findsOneWidget, reason: 'Loyer follows Logement');

    await tester.tap(find.byKey(const Key('detachedMove-Logement')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(SimpleDialog), matching: find.text('Dépenses')));
    await settle(tester);

    expect(find.text('À replacer'), findsNothing);
    expect(find.byKey(const Key('categoryMenu-Logement')), findsOneWidget);
    expect(find.byKey(const Key('categoryMenu-Nourriture')), findsOneWidget);
    expect(find.byKey(const Key('categoryMenu-Loyer')), findsOneWidget);
  });

  testWidgets('rules: a tap on a category opens its menu, a rule added there shows under it; transfers and help', (
    tester,
  ) async {
    final services = await pumpApp(tester);
    final year = DateTime.now().year;
    await tester.runAsync(() async {
      var ledger = await services.ledger.load();
      await services.ledger.write(ledger.createTree(year));
      ledger = await services.ledger.load();
      await services.ledger.write(
        ledger.addCategory(
          'food',
          year: year,
          name: 'Nourriture',
          parentId: defaultGroupId(year, CategoryNature.expense),
        ),
      );
      ledger = await services.ledger.load();
      await services.ledger.write(
        ledger.createAccount('cash', const AccountDraft(name: 'Espèces', type: AccountType.cash)),
      );
    });
    unawaited(tester.element(find.byType(AppShell)).read<LedgerCubit>().load());
    await settle(tester);
    await openCategories(tester);

    // A tap on the category itself opens the same menu as its button.
    await tester.tap(find.text('Nourriture'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter une sous-catégorie'), findsOneWidget);
    await tester.tap(find.text('Ajouter une règle'));
    await tester.pumpAndSettle();
    expect(find.text('Classe dans « Nourriture »'), findsOneWidget, reason: 'the rule belongs to its category');
    expect(find.byKey(const Key('ruleCategory')), findsNothing);
    await tester.enterText(find.byKey(const Key('ruleKeywords')), 'migros\ncoop ET pronto');
    await tester.tap(find.byKey(const Key('ruleSave')));
    await settle(tester);
    expect(find.text('migros\ncoop ET pronto'), findsOneWidget, reason: 'under its category, one line each');

    // The help explains OU and ET.
    await tester.tap(find.byKey(const Key('rulesHelp')));
    await tester.pumpAndSettle();
    expect(find.textContaining('joignez-les par ET en majuscules'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    // A transfer rule chooses its account and shows under it.
    await tester.scrollUntilVisible(find.byKey(const Key('addTransferRule')), 200);
    await tester.tap(find.byKey(const Key('addTransferRule')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ruleKeywords')), 'retrait bancomat');
    await tester.tap(find.byKey(const Key('ruleAccount')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Espèces').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ruleSave')));
    await settle(tester);
    expect(find.byKey(const ValueKey('transferRules-cash')), findsOneWidget);
    expect(find.text('retrait bancomat'), findsOneWidget);

    // Deleting the category says its rules go with it.
    await menu(tester, 'Nourriture', 'Supprimer');
    expect(find.text('Supprimer la catégorie « Nourriture » et sa règle ?'), findsOneWidget);
    await tester.tap(find.text('Supprimer').last);
    await settle(tester);
    expect(find.text('migros\ncoop ET pronto'), findsNothing);
    final ledger = await tester.runAsync(services.ledger.load);
    expect(ledger!.rules.values.map((r) => r.lines), [
      ['retrait bancomat'],
    ]);
  });
}
