import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/modules/salary.dart';
import 'package:batz/domain/modules/settings.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show settle;

void main() {
  late AppServices services;
  final today = CalendarDate(2026, 11, 21);

  Future<Ledger> ledger(WidgetTester tester) async => (await tester.runAsync(services.ledger.load))!;

  Future<void> openSalary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = (await tester.runAsync(() => testServices(today: () => today)))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await tester.runAsync(() async {
      final l = await services.ledger.load();
      await services.ledger.write(l.createTree(2026));
      final l2 = await services.ledger.load();
      await services.ledger.write(
        l2.addCategory('salary', year: 2026, name: 'Salaire', parentId: defaultGroupId(2026, CategoryNature.income)),
      );
    });
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
    await settle(tester);
    expect(find.text('Analyses'), findsOneWidget);
    await tester.tap(find.byKey(const Key('moreSalary')));
    await settle(tester);
  }

  testWidgets('the sheet of the example: labels proposed, gap computed as typed, saved, modified, deleted', (
    tester,
  ) async {
    await openSalary(tester);
    expect(find.text('Catégorie liée : « Salaire »'), findsOneWidget);
    expect(find.text("Trouvée dans l'arbre de 2026."), findsOneWidget);
    for (final (i, label) in ['AVS', 'AC', 'LPP'].indexed) {
      expect(tester.widget<TextField>(find.byKey(ValueKey('salaryDeductionLabel-$i'))).controller!.text, label);
    }
    await tester.enterText(find.byKey(const Key('salaryGross')), "96'000");
    await tester.enterText(find.byKey(const ValueKey('salaryDeductionAmount-0')), "5'088");
    await tester.enterText(find.byKey(const ValueKey('salaryDeductionAmount-1')), "1'056");
    await tester.enterText(find.byKey(const ValueKey('salaryDeductionAmount-2')), "6'000");
    await tester.enterText(find.byKey(const Key('salaryNet')), "83'856");
    await tester.pump();
    expect(find.text("Total des déductions : 12'144.00"), findsOneWidget);
    expect(find.byKey(const Key('salaryBalanced')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('salaryNet')), "83'800");
    await tester.pump();
    expect(find.text('Écart : 56.00 (brut moins déductions moins net)'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('salarySave')));
    await tester.tap(find.byKey(const Key('salarySave')));
    await settle(tester);
    expect(find.text('Fiche salaire enregistrée.'), findsOneWidget);
    var sheet = (await ledger(tester)).salarySheet(2026)!;
    expect((sheet.gross, sheet.net, sheet.deductionsTotal, sheet.gap), (9600000, 8380000, 1214400, 5600));

    // A deduction added, one removed.
    await tester.tap(find.byKey(const ValueKey('salaryDeductionRemove-1')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('salaryDeductionAdd')));
    await tester.tap(find.byKey(const Key('salaryDeductionAdd')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('salaryDeductionLabel-2')), 'AANP');
    await tester.enterText(find.byKey(const ValueKey('salaryDeductionAmount-2')), '100');
    await tester.ensureVisible(find.byKey(const Key('salarySave')));
    await tester.tap(find.byKey(const Key('salarySave')));
    await settle(tester);
    sheet = (await ledger(tester)).salarySheet(2026)!;
    expect(sheet.deductions.map((d) => (d.label, d.amount)), [('AVS', 508800), ('LPP', 600000), ('AANP', 10000)]);

    // A label left empty is refused with its reason.
    await tester.enterText(find.byKey(const ValueKey('salaryDeductionLabel-2')), '');
    await tester.ensureVisible(find.byKey(const Key('salarySave')));
    await tester.tap(find.byKey(const Key('salarySave')));
    await settle(tester);
    expect(find.text('Chaque déduction a un libellé.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('salaryDelete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await settle(tester);
    expect((await ledger(tester)).salarySheet(2026), isNull);
  });

  testWidgets('the name of the category of the salary changes from the screen; a name missing from the tree is '
      'said, without error', (tester) async {
    await openSalary(tester);
    await tester.tap(find.byKey(const ValueKey('moduleCategory-salary')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('moduleCategoryName')), 'Rémunération');
    await tester.tap(find.byKey(const Key('moduleCategorySave')));
    await settle(tester);
    expect(find.text('Catégorie liée : « Rémunération »'), findsOneWidget);
    expect(find.text("Aucune catégorie de ce nom dans l'arbre de 2026."), findsOneWidget);
    expect((await ledger(tester)).moduleCategoryName(ModuleKind.salary), 'Rémunération');
  });
}
