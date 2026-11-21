import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/proposal.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/ledger/refund.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/views/share_operations.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/services.dart';
import '../../support/statements.dart';
import '../accounts/accounts_page_test.dart' show settle;

void main() {
  final year = CalendarDate.today().year;
  late AppServices services;

  Future<Ledger> ledger(WidgetTester tester) async => (await tester.runAsync(services.ledger.load))!;

  Future<void> write(WidgetTester tester, Modification Function(Ledger l) build) =>
      tester.runAsync(() async => services.ledger.write(build(await services.ledger.load())));

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = (await tester.runAsync(testServices))!;
    addTearDown(() => tester.runAsync(services.database.close));
  }

  Future<void> pick(WidgetTester tester, Key dropdown, String item) async {
    await tester.tap(find.byKey(dropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  Future<void> nav(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
    await settle(tester);
  }

  String text(WidgetTester tester, Key key) => tester.widget<Text>(find.byKey(key)).data!;

  testWidgets('a refund attached at validation: the expense shows it and its net cost', (tester) async {
    await start(tester);
    final january = fixtureStatement('2026-01');
    await write(
      tester,
      (l) => l.createAccount(
        'bank',
        const AccountDraft(
          name: 'PostFinance',
          type: AccountType.privateAccount,
          importFormat: ImportFormat.postfinance,
        ),
      ),
    );
    await write(tester, (l) => l.createTree(2026));
    await write(
      tester,
      (l) =>
          l.addCategory('shopping', year: 2026, name: 'Achats', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
    await write(
      tester,
      (l) => l.importStatement('bank', january.statement, fingerprint: january.fingerprint).modification,
    );
    final lines = (await ledger(tester)).linesToValidate;
    final purchase = lines.firstWhere((t) => t.rawText!.startsWith('ACHAT/SERVICE DU 11.01.2026'));
    final credit = lines.firstWhere((t) => t.rawText!.startsWith('CRÉDIT POSTFINANCE CARD'));
    await write(
      tester,
      (l) => l.classify(
        purchase.id,
        Classification.category('shopping', periodStart: purchase.date, periodEnd: purchase.date),
      ),
    );
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);

    // The credit is validated as the refund of the purchase.
    await tester.tap(find.byKey(const Key('taskLinesToValidate')));
    await settle(tester);
    final item = find.byKey(ValueKey('toComplete-${credit.id}'));
    await tester.dragUntilVisible(item, find.byKey(const Key('toCompleteList')), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(item);
    await settle(tester);
    await tester.tap(find.text('Remboursement'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez la dépense remboursée.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('classifyPickExpense')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('refundSearch')), 'grand magasin');
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('refundTarget-${credit.id}')), findsNothing, reason: 'money that came in');
    await tester.tap(find.byKey(ValueKey('refundTarget-${purchase.id}')));
    await settle(tester);
    expect(find.byKey(const Key('classifyExpense')), findsOneWidget);
    await tester.tap(find.byKey(const Key('classifyValidate')));
    await settle(tester);
    final attached = (await ledger(tester)).transactions[credit.id]!;
    expect((attached.isValidated, attached.line!.refundedLineId), (true, '${purchase.id}-line'));
    await tester.tap(find.byType(BackButton).last);
    await settle(tester);

    // The purchase shows its refund and its net cost.
    await nav(tester, 'Transactions');
    await tester.enterText(find.byKey(const Key('transactionsSearch')), purchase.description);
    await tester.pumpAndSettle();
    // The credit has the same description: the purchase is the one with its
    // amount.
    await tester.tap(find.ancestor(of: find.text(formatted(purchase.amount)), matching: find.byType(ListTile)));
    await settle(tester);
    expect(find.byKey(ValueKey('refund-${credit.id}')), findsOneWidget);
    expect(text(tester, const Key('netCost')), formatted(purchase.amount + credit.amount));

    // The refund shows its expense, and is detached there.
    await tester.tap(find.byKey(ValueKey('refund-${credit.id}')));
    await settle(tester);
    expect(find.byKey(const Key('refundedExpense')), findsOneWidget);
    await tester.tap(find.byKey(const Key('detachRefund')));
    await settle(tester);
    expect(find.byKey(const Key('refundedExpense')), findsNothing);
    expect(find.byKey(const Key('attachRefund')), findsOneWidget);
    expect((await ledger(tester)).refundsOf((await ledger(tester)).transactions[purchase.id]!), isEmpty);
  });

  testWidgets('a share to classify: a task at home, the answer for the group, then the amount in its category', (
    tester,
  ) async {
    await start(tester);
    await write(tester, (l) => l.createAccount('cash', const AccountDraft(name: 'Espèces', type: AccountType.cash)));
    await write(tester, (l) => l.createTree(year - 1));
    await write(
      tester,
      (l) => l.addCategory(
        'food',
        year: year - 1,
        name: 'Nourriture',
        parentId: defaultGroupId(year - 1, CategoryNature.expense),
      ),
    );
    await write(tester, (l) => l.createTree(year));
    final food = copiedCategoryId('food', year);
    await write(tester, (l) => l.renameCategory(food, 'Alimentation'));
    await write(
      tester,
      (l) => l.recordEntry(
        'market',
        'market-line',
        EntryDraft(
          accountId: 'cash',
          date: CalendarDate(year - 1, 7, 1),
          cents: 120000,
          direction: Direction.outflow,
          categoryId: 'food',
          description: 'Abonnement au marché',
          periodStart: CalendarDate(year - 1, 7, 1),
          periodEnd: CalendarDate(year, 6, 30),
        ),
      ),
    );
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);

    expect(find.text('Une part à classer'), findsOneWidget);
    // Meanwhile the year shows it in « À classer », among the expenses.
    await nav(tester, 'Année');
    expect(text(tester, const ValueKey('yearAmount-toClassify-expense')), '600.00');
    await tester.tap(find.byKey(const ValueKey('yearAmount-toClassify-expense')));
    await settle(tester);
    expect(find.text('Parts à classer'), findsOneWidget);
    expect(find.text('Abonnement au marché'), findsOneWidget);
    final key = 'food-$year';
    await pick(tester, ValueKey('sharesCategory-$key'), 'Alimentation');
    await tester.tap(find.byKey(ValueKey('sharesClassify-$key')));
    await settle(tester);
    expect(find.text('Aucune part à classer.'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.byKey(const ValueKey('yearLine-toClassify-expense')), findsNothing);
    expect(text(tester, ValueKey('yearAmount-$food')), '600.00');
    await nav(tester, 'Accueil');
    expect(find.text('Une part à classer'), findsNothing);
    final answered = await ledger(tester);
    expect(answered.views.answerOf('market-line', year)!.categoryId, food);
    expect(answered.pendingShareCount, 0);
  });

  testWidgets('a redistribution rule created in Plus shows its two lines in the year', (tester) async {
    await start(tester);
    await write(tester, (l) => l.createAccount('cash', const AccountDraft(name: 'Espèces', type: AccountType.cash)));
    await write(tester, (l) => l.createTree(year));
    final expenses = defaultGroupId(year, CategoryNature.expense);
    await write(tester, (l) => l.addCategory('food', year: year, name: 'Nourriture', parentId: expenses));
    await write(tester, (l) => l.addCategory('cleaning', year: year, name: 'Entretien ménage', parentId: expenses));
    await write(
      tester,
      (l) => l.recordEntry(
        'groceries',
        'gl',
        EntryDraft(
          accountId: 'cash',
          date: CalendarDate(year, 3, 10),
          cents: 34567,
          direction: Direction.outflow,
          categoryId: 'food',
        ),
      ),
    );
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);

    await nav(tester, 'Plus');
    await tester.tap(find.byKey(const Key('moreRedistribution')));
    await settle(tester);
    expect(find.text('Aucune règle de redistribution cette année.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('redistributionNew')));
    await settle(tester);
    await pick(tester, const Key('redistributionSource'), 'Nourriture · dépenses');
    await pick(tester, const Key('redistributionTarget'), 'Nourriture · dépenses');
    await tester.enterText(find.byKey(const Key('redistributionPercent')), '10');
    await tester.tap(find.byKey(const Key('redistributionSave')));
    await settle(tester);
    expect(find.text('La source et la cible doivent être deux catégories différentes.'), findsOneWidget);
    await pick(tester, const Key('redistributionTarget'), 'Entretien ménage · dépenses');
    await tester.enterText(find.byKey(const Key('redistributionPercent')), '120');
    await tester.tap(find.byKey(const Key('redistributionSave')));
    await settle(tester);
    expect(find.text('Indiquez un pourcentage entre 0.01 et 100, avec deux décimales au plus.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('redistributionPercent')), '10');
    await tester.tap(find.byKey(const Key('redistributionSave')));
    await settle(tester);
    expect(find.text('De Nourriture vers Entretien ménage'), findsOneWidget);
    expect(find.text('10 %'), findsOneWidget);
    final rule = (await ledger(tester)).redistributionsOf(year).single;

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await nav(tester, 'Année');
    expect(find.text('Vers Entretien ménage · 10 %'), findsOneWidget);
    expect(find.text('Depuis Nourriture · 10 %'), findsOneWidget);
    expect(text(tester, ValueKey('yearAmount-redistribution-${rule.id}-source')), '-34.57');
    expect(text(tester, ValueKey('yearAmount-redistribution-${rule.id}-target')), '34.57');
    expect(text(tester, const ValueKey('yearAmount-food')), '345.67');
    expect(text(tester, ValueKey('yearAmount-$expenses')), '345.67');
    // Month by month, in both views.
    await tester.tap(find.byKey(ValueKey('yearMonths-redistribution-${rule.id}-target')));
    await settle(tester);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('yearMonth-redistribution-${rule.id}-target-3')),
        matching: find.text('34.57'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Trésorerie'));
    await settle(tester);
    expect(text(tester, ValueKey('yearAmount-redistribution-${rule.id}-target')), '34.57');
    expect((await ledger(tester)).views.of(year, ViewKind.cash)!.redistributions.single.moved.month(3), -3457);
  });
}

String formatted(int cents) {
  final negative = cents < 0;
  final digits = cents.abs().toString().padLeft(3, '0');
  final whole = digits.substring(0, digits.length - 2);
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write("'");
    grouped.write(whole[i]);
  }
  return '${negative ? '-' : ''}$grouped.${digits.substring(digits.length - 2)}';
}
