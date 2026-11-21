import 'dart:io';

import 'package:batz/app.dart';
import 'package:batz/version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/services.dart';

void main() {
  testWidgets('« Plus » shows the version of the app, the one of pubspec.yaml', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = (await tester.runAsync(testServices))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await tester.pumpWidget(BatzApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
    await tester.pumpAndSettle();
    final version = find.byKey(const Key('moreVersion'));
    await tester.scrollUntilVisible(version, 200);

    // The version name of pubspec.yaml, its suffix included, without the
    // build number.
    final declared = RegExp(
      r'^version:\s*([^+\s]+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;
    expect(appVersion, declared);
    expect(tester.widget<Text>(version).data, 'batz $declared');
  });
}
