import 'dart:math';

import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/flow.dart';
import 'package:batz/domain/modules/module_records.dart';
import 'package:batz/domain/modules/salary.dart';
import 'package:batz/domain/modules/settings.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/flow_example.dart';
import '../../support/ledger_harness.dart';
import '../../support/random_ledger.dart';

/// A node as the screen names it, and its amount.
(String, int) node(FlowNode n) => (
  switch (n.kind) {
    FlowNodeKind.grossSalary => 'Salaire brut',
    FlowNodeKind.deduction => n.label!,
    FlowNodeKind.groupRest => '${n.category!.name} hors ${n.without.map((c) => c.name).join(' et ')}',
    FlowNodeKind.toClassify => 'À classer ${n.nature!.name}',
    FlowNodeKind.fromWealth => 'Puisé dans la fortune',
    FlowNodeKind.savings => 'Épargne',
    _ => n.category!.name,
  },
  n.amount,
);

/// What every diagram must satisfy: both sides make the same total, the
/// bands carry each node's amount, and the nodes give back the income, the
/// expenses and the savings of the view.
void checkDiagram(Ledger ledger, FlowDiagram diagram, {required String reason}) {
  final view = ledger.views.of(diagram.year, diagram.kind)!;
  expect(diagram.leftTotal, diagram.rightTotal, reason: '$reason: both sides');
  for (final (i, n) in diagram.left.indexed) {
    expect(diagram.links.where((l) => l.from == i).fold(0, (s, l) => s + l.amount), n.amount, reason: reason);
  }
  for (final (j, n) in diagram.right.indexed) {
    expect(diagram.links.where((l) => l.to == j).fold(0, (s, l) => s + l.amount), n.amount, reason: reason);
  }
  final all = [...diagram.left, ...diagram.right];
  int signed(CategoryNature? nature) => all.where((n) => n.nature == nature).fold(0, (s, n) => s + n.signed);
  expect(signed(CategoryNature.income), view.income.total, reason: '$reason: income');
  expect(signed(CategoryNature.expense), view.expenses.total, reason: '$reason: expenses');
  expect(-signed(null), view.savings.total, reason: '$reason: savings');
  expect(all.every((n) => n.amount > 0), isTrue, reason: '$reason: no node of zero');
}

void main() {
  late LedgerHarness h;
  setUp(() async => h = await LedgerHarness.open());
  tearDown(() => h.close());

  test('the example with the salary sheet starts from the gross: 96\'144.00 on each side, every node', () async {
    final ledger = await flowExample(h.apply);
    for (final kind in ViewKind.values) {
      final diagram = flowDiagram(ledger, 2026, kind)!;
      expect(diagram.fromGross, isTrue);
      expect(diagram.left.map(node), [('Salaire brut', 9600000), ('Revenus hors Salaire', 14400)]);
      expect(diagram.right.map(node), [
        ('AVS', 508800),
        ('AC', 105600),
        ('LPP', 600000),
        ('Impôts', 1500000),
        ('Logement', 2400000),
        ('Quotidien', 1800000),
        ('Obligations hors Impôts', 600000),
        ('Épargne', 2100000),
      ]);
      expect((diagram.leftTotal, diagram.rightTotal), (9614400, 9614400));
      expect(diagram.grossGap, 0);
      checkDiagram(ledger, diagram, reason: kind.name);
    }
    // The gross splits between each deduction and the net.
    final diagram = flowDiagram(ledger, 2026, ViewKind.economic)!;
    expect(
      [
        for (final l in diagram.links)
          if (l.from == 0) (diagram.right[l.to].key.startsWith('deduction'), l.amount),
      ].take(3),
      [(true, 508800), (true, 105600), (true, 600000)],
    );
  });

  test('without salary sheet it starts from the net: 84\'000.00 on each side', () async {
    final ledger = await flowExample(h.apply, sheet: false);
    final diagram = flowDiagram(ledger, 2026, ViewKind.cash)!;
    expect(diagram.fromGross, isFalse);
    expect(diagram.grossGap, isNull);
    expect(diagram.left.map(node), [('Salaire', 8385600), ('Revenus hors Salaire', 14400)]);
    expect(diagram.right.map(node), [
      ('Impôts', 1500000),
      ('Logement', 2400000),
      ('Quotidien', 1800000),
      ('Obligations hors Impôts', 600000),
      ('Épargne', 2100000),
    ]);
    expect((diagram.leftTotal, diagram.rightTotal), (8400000, 8400000));
    checkDiagram(ledger, diagram, reason: 'net');
  });

  test('with 83\'000.00 received only, the gross of the diagram is 95\'144.00 and the gap with the gross entered, '
      '-856.00, is signalled', () async {
    final ledger = await flowExample(h.apply, salary: 8300000);
    final diagram = flowDiagram(ledger, 2026, ViewKind.economic)!;
    expect(node(diagram.left.first), ('Salaire brut', 9514400));
    expect(diagram.grossGap, -85600);
    checkDiagram(ledger, diagram, reason: 'gap');
  });

  test('expenses above income give « Puisé dans la fortune » on the left, and no « Épargne »', () async {
    await flowExample(h.apply, sheet: false);
    final ledger = await h.apply(
      (l) => l.recordEntry(
        'car',
        'car-line',
        EntryDraft(
          accountId: 'cash',
          date: CalendarDate(2026, 7, 1),
          cents: 3000000,
          direction: Direction.outflow,
          categoryId: 'spare',
        ),
      ),
    );
    final diagram = flowDiagram(ledger, 2026, ViewKind.cash)!;
    expect(diagram.left.map(node).last, ('Puisé dans la fortune', 900000));
    expect(diagram.right.map((n) => n.kind), isNot(contains(FlowNodeKind.savings)));
    expect(diagram.right.map(node), contains(('Quotidien', 4800000)));
    checkDiagram(ledger, diagram, reason: 'from wealth');
  });

  test('a group of expenses that is a gain goes to the left; a negative income to the right', () async {
    await flowExample(h.apply, sheet: false);
    await h.apply(
      (l) => l.recordEntry(
        'refund',
        'refund-line',
        EntryDraft(
          accountId: 'cash',
          date: CalendarDate(2026, 7, 1),
          cents: 2500000,
          direction: Direction.inflow,
          categoryId: 'rent',
        ),
      ),
    );
    final ledger = await h.apply(
      (l) => l.recordEntry(
        'clawback',
        'clawback-line',
        EntryDraft(
          accountId: 'cash',
          date: CalendarDate(2026, 7, 2),
          cents: 20000,
          direction: Direction.outflow,
          categoryId: 'interest',
        ),
      ),
    );
    final diagram = flowDiagram(ledger, 2026, ViewKind.cash)!;
    expect(diagram.left.map(node), contains(('Logement', 100000)));
    expect(diagram.right.map(node), contains(('Revenus hors Salaire', 5600)));
    checkDiagram(ledger, diagram, reason: 'signs');
  });

  test('the category of the salary or of the taxes missing from the tree: the diagram starts from the net, the '
      'groups whole', () async {
    await flowExample(h.apply);
    await h.apply((l) => l.setModuleCategory(ModuleKind.salary, 'Rémunération'));
    final ledger = await h.apply((l) => l.setModuleCategory(ModuleKind.taxes, 'Contributions'));
    final diagram = flowDiagram(ledger, 2026, ViewKind.economic)!;
    expect((diagram.salaryCategory, diagram.taxesCategory, diagram.fromGross), (null, null, false));
    expect(diagram.left.map(node), [('Revenus', 8400000)]);
    expect(diagram.right.map(node), [
      ('Logement', 2400000),
      ('Quotidien', 1800000),
      ('Obligations', 2100000),
      ('Épargne', 2100000),
    ]);
    checkDiagram(ledger, diagram, reason: 'missing');
    expect(flowDiagram(ledger, 2025, ViewKind.economic), isNull, reason: 'a year before the first tree');
  });

  test('on random data, for each year and view, both sides make the same total and the nodes give back the '
      'income, the expenses and the savings of the view', () {
    for (var seed = 1; seed <= 15; seed++) {
      final r = Random(seed);
      final base = randomLedger(r);
      final sheets = [
        for (final year in [2026, 2028])
          if (r.nextBool())
            SalarySheet(id: salarySheetId(year), year: year, gross: 1 + r.nextInt(10000000), net: r.nextInt(8000000)),
      ];
      final ledger = Ledger(
        accounts: base.accounts.values,
        categories: [for (final tree in base.trees.values) ...tree.byId.values],
        transactions: base.transactions.values,
        rules: base.rules.values,
        redistributions: base.redistributions.values,
        shareClassifications: base.shareClassifications.values,
        modules: ModuleRecords(
          salarySheets: sheets,
          salaryDeductions: [
            for (final s in sheets)
              for (var i = 0; i < 3; i++)
                SalaryDeduction(id: '${s.id}-$i', sheetId: s.id, label: 'D$i', amount: r.nextInt(500000), rank: i),
          ],
        ),
      );
      for (final year in randomYears) {
        for (final kind in ViewKind.values) {
          final diagram = flowDiagram(ledger, year, kind)!;
          checkDiagram(ledger, diagram, reason: 'seed $seed, $year ${kind.name}');
          expect(diagram.taxesCategory != null, year >= 2027, reason: '« Impôts » from 2027');
          expect(diagram.fromGross, sheets.any((s) => s.year == year));
        }
      }
    }
  });
}
