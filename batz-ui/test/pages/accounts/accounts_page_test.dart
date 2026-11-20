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

Future<void> createAccount(WidgetTester tester, String name, {String? type, bool detailed = false}) async {
  await tester.tap(find.byTooltip('Nouveau compte'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('accountName')), name);
  if (type != null) {
    await tester.tap(find.byKey(const Key('accountType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(type).last);
    await tester.pumpAndSettle();
  }
  if (detailed) await tester.tap(find.text('Import des relevés PostFinance'));
  await tester.tap(find.text('Enregistrer'));
  await settle(tester);
}

void main() {
  testWidgets('accounts: create, refuse a second detailed account, delete', (tester) async {
    await pumpApp(tester);
    await openAccounts(tester);
    expect(find.text('Aucun compte. Créez-en un avec le bouton +.'), findsOneWidget);

    await createAccount(tester, 'PostFinance', detailed: true);
    expect(find.text('PostFinance'), findsOneWidget);
    expect(find.text('Compte privé · Détaillé'), findsOneWidget);

    await createAccount(tester, 'Espèces', type: 'Espèces');
    expect(find.text('Espèces'), findsNWidgets(2), reason: 'name and type');

    await createAccount(tester, 'UBS', detailed: true);
    expect(
      find.text("Un seul compte peut être détaillé : l'import est déjà activé sur un autre compte."),
      findsOneWidget,
    );
    expect(find.text('Nouveau compte'), findsOneWidget, reason: 'the form stays open');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('UBS'), findsNothing);

    await tester.tap(find.text('PostFinance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await settle(tester);
    expect(find.text('Compte supprimé.'), findsOneWidget);
    expect(find.text('PostFinance'), findsNothing);
  });
}
