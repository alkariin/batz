import 'package:batz/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/services.dart';

const _labels = ['Accueil', 'Transactions', 'Année', 'Fortune', 'Plus'];

Future<void> _pumpApp(WidgetTester tester, Size size, {Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  final services = (await tester.runAsync(testServices))!;
  addTearDown(() => tester.runAsync(services.database.close));
  await tester.pumpWidget(BatzApp(services: services));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('narrow screen: five entries in a bottom bar', (tester) async {
    await _pumpApp(tester, const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    final bar = find.byType(NavigationBar);
    for (final label in _labels) {
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    expect(find.widgetWithText(AppBar, 'Accueil'), findsOneWidget);

    await tester.tap(find.descendant(of: bar, matching: find.text('Fortune')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Fortune'), findsOneWidget);
    expect(
      find.text("Aucun solde déclaré ni aucune dette : déclarez le solde d'un compte pour suivre votre fortune."),
      findsOneWidget,
    );
  });

  testWidgets('wide screen: five entries in a side rail', (tester) async {
    await _pumpApp(tester, const Size(1280, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = find.byType(NavigationRail);
    for (final label in _labels) {
      expect(
        find.descendant(of: rail, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }

    await tester.tap(find.descendant(of: rail, matching: find.text('Année')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Année'), findsOneWidget);
  });

  testWidgets('the selected section survives a resize', (tester) async {
    await _pumpApp(tester, const Size(400, 800));
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Plus'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Material 3 theme follows the device: $brightness', (tester) async {
      await _pumpApp(tester, const Size(400, 800), brightness: brightness);
      final theme = Theme.of(tester.element(find.byType(Scaffold).first));
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, brightness);
    });
  }

  testWidgets('texts are in French', (tester) async {
    await _pumpApp(tester, const Size(400, 800));
    final context = tester.element(find.byType(Scaffold).first);
    expect(Localizations.localeOf(context).languageCode, 'fr');
    expect(MaterialLocalizations.of(context).okButtonLabel, 'OK');
    expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Annuler');
  });

  testWidgets('a start-up failure is explained instead of a blank screen', (tester) async {
    await tester.pumpWidget(StartupErrorApp(error: StateError('database key lost')));
    await tester.pumpAndSettle();
    expect(find.text('batz ne peut pas démarrer'), findsOneWidget);
    expect(find.textContaining('database key lost'), findsOneWidget);
  });
}
