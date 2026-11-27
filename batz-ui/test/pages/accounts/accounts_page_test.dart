import 'package:batz/app.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/services.dart';

Future<AppServices> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final services = (await tester.runAsync(testServices))!;
  addTearDown(() => tester.runAsync(services.database.close));
  await tester.pumpWidget(BatzApp(services: services));
  await tester.pumpAndSettle();
  return services;
}

/// Lets database work started by a tap complete, then redraws.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }
}

Future<void> openAccounts(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Comptes'));
  await tester.pumpAndSettle();
}

Future<void> createAccount(WidgetTester tester, String name, {String? type, String? import}) async {
  await tester.tap(find.byTooltip('Nouveau compte'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('accountName')), name);
  if (type != null) {
    await tester.tap(find.byKey(const Key('accountType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(type).last);
    await tester.pumpAndSettle();
  }
  if (import != null) {
    await tester.tap(find.byKey(const Key('accountImport')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(import).last);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Enregistrer'));
  await settle(tester);
}

void main() {
  testWidgets('accounts: create, two detailed accounts of different formats, delete', (tester) async {
    await pumpApp(tester);
    await openAccounts(tester);
    expect(find.text('Aucun compte. Créez-en un avec le bouton +.'), findsOneWidget);

    await createAccount(tester, 'PostFinance', import: 'Relevés PDF PostFinance');
    expect(find.text('PostFinance'), findsOneWidget);
    expect(find.text('Compte privé · Détaillé'), findsOneWidget);

    await createAccount(tester, 'Espèces', type: 'Espèces');
    expect(find.text('Espèces'), findsNWidgets(2), reason: 'name and type');

    await createAccount(tester, 'Neon', import: 'Exports CSV Neon');
    expect(find.text('Compte privé · Détaillé'), findsNWidgets(2));
    await tester.tap(find.text('Neon'));
    await tester.pumpAndSettle();
    expect(find.text('Exports CSV Neon'), findsOneWidget, reason: 'the format chosen');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PostFinance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await settle(tester);
    expect(find.text('Compte supprimé.'), findsOneWidget);
    expect(find.text('PostFinance'), findsNothing);
  });

  testWidgets(
    'accounts: moved by their menu; one declared in the tax return shows in colour, here and in « Fortune »',
    (tester) async {
      await pumpApp(tester);
      await openAccounts(tester);
      await createAccount(tester, 'Banque');
      await createAccount(tester, 'Porte-monnaie', type: 'Espèces');
      await createAccount(tester, 'Tirelire', type: 'Épargne');
      double top(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(top('Banque') < top('Tirelire') && top('Tirelire') < top('Porte-monnaie'), isTrue, reason: 'by type');

      await tester.tap(find.byKey(const Key('accountMenu-Porte-monnaie')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monter'));
      await settle(tester);
      expect(top('Banque') < top('Porte-monnaie') && top('Porte-monnaie') < top('Tirelire'), isTrue);
      await tester.tap(find.byKey(const Key('accountMenu-Banque')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descendre'));
      await settle(tester);
      expect(top('Porte-monnaie') < top('Banque') && top('Banque') < top('Tirelire'), isTrue);

      await tester.tap(find.text('Tirelire'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accountDeclared')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);
      expect(find.text('Épargne · Déclaré aux impôts'), findsOneWidget);
      final colour = Theme.of(tester.element(find.text('Tirelire'))).colorScheme.tertiary;
      expect(tester.widget<Text>(find.text('Tirelire')).style?.color, colour);
      expect(tester.widget<Text>(find.text('Banque')).style?.color, isNot(colour));

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Fortune')));
      await settle(tester);
      expect(find.byKey(const Key('wealthDeclaredLegend')), findsOneWidget);
      expect(tester.widget<Text>(find.text('Tirelire')).style?.color, colour);
    },
  );
}
