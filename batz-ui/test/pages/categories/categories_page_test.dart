import 'package:batz/pages/categories/categories_page.dart';
import 'package:flutter/material.dart';
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
}
