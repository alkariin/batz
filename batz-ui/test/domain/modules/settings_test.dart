import 'dart:math';

import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/electricity.dart';
import 'package:batz/domain/modules/settings.dart';
import 'package:batz/domain/modules/taxes.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/module_checks.dart';
import '../../support/random_ledger.dart';
import '../../support/statements.dart';

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
  });
  tearDown(() => h.close());

  group('the lines the annual view counts, read by the modules', () {
    test('in a category of a year: what each line places there month by month, before redistribution, the '
        'lines to validate as proposed and an attached refund following its expense', () async {
      await h.apply((l) => l.addCategory('cleaning', year: 2026, name: 'Entretien ménage', parentId: 'housing'));
      await h.apply(
        (l) => l.createRedistribution(
          'ten',
          const RedistributionDraft(year: 2026, sourceId: 'food', targetId: 'cleaning', basisPoints: 1000),
        ),
      );
      await h.apply(
        (l) => l.recordEntry(
          'visit',
          'visit-line',
          entry(
            category: 'food',
            cents: 30000,
            date: d(2026, 1, 15),
            periodStart: d(2026, 1, 1),
            periodEnd: d(2026, 3, 31),
          ),
        ),
      );
      await h.apply(
        (l) => l.recordEntry(
          'back',
          'back-line',
          EntryDraft(
            accountId: 'cash',
            date: d(2026, 5, 20),
            cents: 12000,
            direction: Direction.inflow,
            categoryId: null,
            refundedLineId: 'visit-line',
          ),
        ),
      );
      final january = fixtureStatement('2026-01');
      await h.repository.write(
        (await h.ledger()).importStatement('bank', january.statement, fingerprint: january.fingerprint).modification,
      );
      final ledger = await h.apply(
        (l) => l.createRule(
          'groceries',
          const RuleDraft(year: 2026, lines: ['épicerie du coin'], targetCategoryId: 'food'),
        ),
      );
      for (final kind in ViewKind.values) {
        final view = ledger.views.of(2026, kind)!;
        final lines = ledger.views.linesIn(2026, kind, 'food');
        expect(
          lines.fold(MonthlyAmounts.zero, (sum, l) => sum + l.months),
          view.categories['food'],
          reason: 'what « Nourriture » shows before redistribution, ${kind.name}',
        );
        expect(lines.where((l) => !l.line.transaction.isValidated), hasLength(5), reason: 'proposed');
        final refund = lines.singleWhere((l) => l.line.transaction.id == 'back');
        expect((refund.line.ownLineId, refund.line.lineId), ('back-line', 'visit-line'));
        expect((refund.line.start, refund.line.end), (d(2026, 1, 1), d(2026, 3, 31)), reason: 'the expense period');
        expect(ledger.views.linesIn(2026, kind, 'cleaning'), isEmpty, reason: 'redistribution moves no line');
        // A group counts with everything below it.
        expect(
          ledger.views.linesIn(2026, kind, defaultGroupId(2026, CategoryNature.expense)).fold(0, (s, l) => s + l.total),
          view.categories['food']!.total + view.categories['housing']!.total - view.redistributedOf('cleaning').total,
        );
      }
      final economic = ledger.views
          .linesIn(2026, ViewKind.economic, 'food')
          .singleWhere((l) => l.line.transaction.id == 'visit');
      expect(economic.months.months.take(3), [-10000, -10000, -10000]);
    });

    test('on random data, the lines of each category of each year and view make what it shows before '
        'redistribution', () {
      for (var seed = 1; seed <= 5; seed++) {
        final ledger = randomLedger(Random(seed));
        final views = ledger.views;
        for (final year in randomYears) {
          for (final kind in ViewKind.values) {
            final view = views.of(year, kind)!;
            for (final category in view.tree.assignable) {
              final lines = views.linesIn(year, kind, category.id);
              expect(
                lines.fold(MonthlyAmounts.zero, (sum, l) => sum + l.months),
                view.categories[category.id],
                reason: 'seed $seed, $year ${kind.name}, ${category.name}',
              );
            }
          }
        }
      }
    });

    test('by name: the lines classified in the category of that name in the tree of their year, every year', () async {
      await h.apply(
        (l) => l.addCategory(
          'trips',
          year: 2026,
          name: 'Vacances',
          parentId: defaultGroupId(2026, CategoryNature.expense),
        ),
      );
      await h.apply((l) => l.addCategory('flights', year: 2026, name: 'Vols', parentId: 'trips'));
      await h.apply((l) => l.recordEntry('a', 'la', entry(category: 'flights', cents: 64000, date: d(2026, 3, 12))));
      await h.apply((l) => l.recordEntry('b', 'lb', entry(category: 'food', cents: 1000, date: d(2026, 3, 13))));
      await h.apply((l) => l.createTree(2027));
      final ledger = await h.apply(
        (l) => l.recordEntry(
          'c',
          'lc',
          entry(category: copiedCategoryId('flights', 2027), cents: 30000, date: d(2027, 1, 9)),
        ),
      );
      expect(ledger.views.linesNamed('vacances').map((l) => l.ownLineId), ['la', 'lc']);
      expect(ledger.views.linesNamed('Vols').map((l) => l.ownLineId), ['la', 'lc']);
      expect(ledger.views.linesNamed('Voyages'), isEmpty);
    });
  });

  group('module settings', () {
    test('default names; a name chosen is used every year, without case or accents; a group counts with what '
        'it holds; a name missing from a year gives no category, without error', () async {
      var ledger = await h.ledger();
      expect(ModuleKind.values.map(ledger.moduleCategoryName), ['Salaire', 'Impôts', 'Vacances', 'Électricité']);
      expect(ledger.moduleCategory(ModuleKind.salary, 2026)!.id, 'salary');
      expect(ledger.moduleCategory(ModuleKind.taxes, 2026), isNull, reason: 'no « Impôts » in 2026');
      expect(ledger.moduleCategory(ModuleKind.taxes, 2025), isNull, reason: 'no tree in 2025');
      expect(ledger.moduleCategory(ModuleKind.salary, 2027)!.id, copiedCategoryId('salary', 2027), reason: 'preview');

      ledger = await h.apply((l) => l.setModuleCategory(ModuleKind.taxes, '  logement '));
      expect(ledger.moduleCategoryName(ModuleKind.taxes), 'logement');
      final housing = ledger.moduleCategory(ModuleKind.taxes, 2026)!;
      expect(housing.id, 'housing', reason: 'a group');
      await h.apply((l) => l.recordEntry('rent', 'lr', entry(category: 'rent', cents: 150000, date: d(2026, 2, 1))));
      ledger = await h.ledger();
      expect(ledger.views.linesIn(2026, ViewKind.economic, housing.id).single.total, -150000);

      // Renamed in 2026: the module follows the name.
      ledger = await h.apply((l) => l.renameCategory('housing', 'Habitation'));
      expect(ledger.moduleCategory(ModuleKind.taxes, 2026), isNull);
      ledger = await h.apply((l) => l.setModuleCategory(ModuleKind.taxes, 'Habitation'));
      expect(ledger.moduleCategory(ModuleKind.taxes, 2026)!.id, 'housing');
      expect(() => ledger.setModuleCategory(ModuleKind.taxes, ' '), throwsA(isA<LedgerException>()));
    });

    test('the modules follow the name: the control of the taxes and the electricity read the category named, a '
        'group with what it holds; a name missing from a year leaves them empty, without error; a setting changes '
        'neither the views nor the wealth', () async {
      final expenses = defaultGroupId(2026, CategoryNature.expense);
      await h.apply((l) => l.addCategory('duties', year: 2026, name: 'Obligations', parentId: expenses));
      await h.apply((l) => l.addCategory('federal', year: 2026, name: 'Impôt fédéral', parentId: 'duties'));
      await h.apply((l) => l.addCategory('cantonal', year: 2026, name: 'Impôt cantonal', parentId: 'duties'));
      await h.apply((l) => l.recordEntry('f', 'lf', entry(category: 'federal', cents: 200000, date: d(2026, 3, 1))));
      var ledger = await h.apply(
        (l) => l.recordEntry('c', 'lc', entry(category: 'cantonal', cents: 700000, date: d(2026, 4, 1))),
      );
      expect((ledger.taxYear(2026).paid, ledger.electricityYear(2026).categoryFound), (null, false));

      final today = d(2026, 11, 21);
      final before = accountsAndViews(ledger, today);
      ledger = await h.apply((l) => l.setModuleCategory(ModuleKind.taxes, 'obligations'));
      expect(ledger.taxYear(2026).paid, 900000, reason: 'the group, with both taxes');
      ledger = await h.apply((l) => l.setModuleCategory(ModuleKind.taxes, 'Impôt cantonal'));
      expect(ledger.taxYear(2026).paid, 700000);
      ledger = await h.apply((l) => l.setModuleCategory(ModuleKind.electricity, 'Impôt fédéral'));
      expect(ledger.electricityYear(2026).price, 200000);
      ledger = await h.apply((l) => l.renameCategory('federal', 'Courant'));
      expect(ledger.electricityYear(2026).categoryFound, isFalse, reason: 'the name is no longer in the tree');
      ledger = await h.apply((l) => l.setModuleCategory(ModuleKind.electricity, 'courant'));
      expect(ledger.electricityYear(2026).price, 200000);
      expect(ledger.electricityYear(2027).categoryFound, isTrue, reason: 'the copy to come has the name too');
      expect(ledger.electricityYear(2025).categoryFound, isFalse);
      // Only the rename touched the views; the settings changed nothing.
      await h.apply((l) => l.renameCategory('federal', 'Impôt fédéral'));
      expect(accountsAndViews(await h.ledger(), today), before);
    });

    test('two devices naming the category of a module write one setting', () async {
      var wallA = 1000, wallB = 1000;
      final a = await LedgerHarness.open(deviceId: 'aaaaaaaa-0000-4000-8000-000000000000', now: () => wallA);
      final b = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000', now: () => wallB);
      addTearDown(a.close);
      addTearDown(b.close);
      wallA = 5000;
      await a.apply((l) => l.setModuleCategory(ModuleKind.electricity, 'Énergie'));
      wallB = 7000;
      await b.apply((l) => l.setModuleCategory(ModuleKind.electricity, 'Courant'));
      final fromA = await a.journal.entries(), fromB = await b.journal.entries();
      await a.journal.merge(fromB);
      await b.journal.merge(fromA);
      for (final device in [a, b]) {
        expect((await device.ledger()).moduleCategoryName(ModuleKind.electricity), 'Courant');
      }
      expect(await a.tables(['module_settings']), await b.tables(['module_settings']));
    });
  });
}
