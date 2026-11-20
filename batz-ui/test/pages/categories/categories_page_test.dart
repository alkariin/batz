import 'dart:async';

import 'package:batz/domain/journal/hlc.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/pages/categories/categories_page.dart';
import 'package:batz/pages/ledger_cubit.dart';
import 'package:batz/pages/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../accounts/accounts_page_test.dart' show pumpApp, settle;

Future<void> openCategories(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Catégories'));
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
}
