import 'package:batz/app.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/pages/ledger_cubit.dart';
import 'package:batz/pages/shell.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/services.dart';
import '../../support/statements.dart';
import '../accounts/accounts_page_test.dart' show settle;

void main() {
  final january = fixtureStatement('2026-01');
  late AppServices services;

  Future<Ledger> ledger(WidgetTester tester) async => (await tester.runAsync(services.ledger.load))!;

  /// Writes through the cubit of the screens once the app runs, directly
  /// before.
  Future<void> write(WidgetTester tester, Modification Function(Ledger l) build) async {
    final shell = find.byType(AppShell);
    if (shell.evaluate().isEmpty) {
      await tester.runAsync(() async => services.ledger.write(build(await services.ledger.load())));
      return;
    }
    final cubit = tester.element(shell).read<LedgerCubit>();
    await tester.runAsync(() => cubit.write(build(cubit.state.ledger)));
  }

  Future<void> showLine(WidgetTester tester, String id) async {
    final item = find.byKey(ValueKey('toComplete-$id'));
    await tester.dragUntilVisible(item, find.byKey(const Key('toCompleteList')), const Offset(0, -200));
    await tester.pumpAndSettle();
  }

  /// The app, offline (not paired), with January imported.
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = (await tester.runAsync(testServices))!;
    addTearDown(() => tester.runAsync(services.database.close));
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
    await write(
      tester,
      (l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)),
    );
    await write(tester, (l) => l.createTree(2026));
    final expenses = defaultGroupId(2026, CategoryNature.expense);
    await write(tester, (l) => l.addCategory('food', year: 2026, name: 'Nourriture', parentId: expenses));
    await write(tester, (l) => l.addCategory('rent', year: 2026, name: 'Loyer', parentId: expenses));
    await write(
      tester,
      (l) => l.importStatement('bank', january.statement, fingerprint: january.fingerprint).modification,
    );
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
  }

  Future<void> pick(WidgetTester tester, Key dropdown, String item) async {
    await tester.tap(find.byKey(dropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'lines are validated offline: a rule created from a line classifies the others, proposals are confirmed in bulk, '
    'a line is classified by hand',
    (tester) async {
      await open(tester);
      expect(find.byKey(const Key('toValidateBadge')), findsOneWidget);
      expect(find.text('27'), findsOneWidget, reason: 'the badge of Transactions');
      expect(find.text('27 lignes à valider'), findsOneWidget, reason: 'the task of the home screen');

      await tester.tap(find.byKey(const Key('taskLinesToValidate')));
      await settle(tester);
      expect(find.text('À compléter (27)'), findsOneWidget);
      expect(find.text('Proposées (0)'), findsOneWidget);

      // A line to complete shows the whole bank text; a rule is created from it.
      final epicerie = (await ledger(tester)).linesToValidate
          .firstWhere((t) => t.rawText!.contains('Épicerie du Coin'));
      await showLine(tester, epicerie.id);
      await tester.tap(find.byKey(ValueKey('toComplete-${epicerie.id}')));
      await settle(tester);
      expect(tester.widget<SelectableText>(find.byKey(const Key('classifyRawText'))).data, epicerie.rawText);
      await tester.tap(find.byKey(const Key('classifyCreateRule')));
      await settle(tester);
      expect(
        find.text('Épicerie du Coin Fictiville'),
        findsOneWidget,
        reason: 'the keywords start from the description',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('ruleMatches'))).data,
        'Cette règle classerait aucune ligne non validée.',
      );
      await pick(tester, const Key('ruleCategory'), 'Nourriture');
      expect(
        tester.widget<Text>(find.byKey(const Key('ruleMatches'))).data,
        'Cette règle classerait 5 lignes non validées.',
      );
      await tester.enterText(find.byKey(const Key('ruleKeywords')), 'épicerie du coin');
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('ruleMatches'))).data,
        'Cette règle classerait 5 lignes non validées.',
      );
      await tester.enterText(find.byKey(const Key('ruleKeywords')), 'épicerie du coin\nre:(');
      await tester.pumpAndSettle();
      expect(find.text('Expression régulière invalide : re:('), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ruleKeywords')), 'épicerie du coin');
      await tester.tap(find.byKey(const Key('ruleSave')));
      await settle(tester);
      expect(find.byKey(const Key('classifyRawText')), findsOneWidget, reason: 'back to the line');
      await tester.tap(find.byType(BackButton));
      await settle(tester);

      // The rule classified the other lines at once.
      expect(find.text('À compléter (22)'), findsOneWidget);
      expect(find.text('Proposées (5)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tabProposed')));
      await settle(tester);
      expect(find.textContaining('Règle « épicerie du coin »'), findsNWidgets(5));
      // The message of the saved rule goes away; it covers the button.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmProposals')));
      await settle(tester);
      expect(find.text('Proposées (0)'), findsOneWidget);
      expect(find.text('5 lignes validées.'), findsOneWidget);

      // A line to complete classified by hand: a transfer to savings.
      await tester.tap(find.byKey(const Key('tabToComplete')));
      await settle(tester);
      final saving = (await ledger(tester)).linesToValidate.firstWhere((t) => t.rawText!.contains('Compte épargne'));
      await showLine(tester, saving.id);
      await tester.tap(find.byKey(ValueKey('toComplete-${saving.id}')));
      await settle(tester);
      await tester.tap(find.text('Transfert'));
      await tester.pumpAndSettle();
      expect(find.text("L'argent part vers ce compte."), findsOneWidget);
      await pick(tester, const Key('classifyAccount'), 'Épargne');
      await tester.enterText(find.byKey(const Key('classifyNote')), 'Épargne de janvier');
      await tester.tap(find.byKey(const Key('classifyValidate')));
      await settle(tester);
      expect(find.text('À compléter (21)'), findsOneWidget);
      final t = (await ledger(tester)).transactions[saving.id]!;
      expect((t.isValidated, t.counterpartAccountId, t.note), (true, 'savings', 'Épargne de janvier'));

      // A validated line stays modifiable, from its detail.
      await tester.tap(find.byType(BackButton).last);
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Transactions')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('transactionsSearch')), 'épargne de janvier');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.description));
      await settle(tester);
      expect(find.byKey(const Key('classifyImported')), findsOneWidget);
      await tester.tap(find.byKey(const Key('classifyImported')));
      await settle(tester);
      await tester.tap(find.text('Catégorie').first);
      await tester.pumpAndSettle();
      await pick(tester, const Key('classifyCategory'), 'Loyer');
      await tester.tap(find.byKey(const Key('classifyValidate')));
      await settle(tester);
      final changed = (await ledger(tester)).transactions[saving.id]!;
      expect((changed.isValidated, changed.counterpartAccountId, changed.line?.categoryId), (true, null, 'rent'));
      await tester.tap(find.byType(BackButton).last);
      await settle(tester);

      // The rules of the year, in Plus.
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
      await settle(tester);
      await tester.tap(find.text('Règles de classement'));
      await settle(tester);
      expect(find.text('épicerie du coin'), findsOneWidget);
      expect(find.text('Nourriture · Date du paiement'), findsOneWidget);
    },
  );

  testWidgets('the transactions list searches text and filters by status; it recalls the lines to validate', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Transactions')));
    await settle(tester);
    expect(find.byKey(const Key('transactionsToValidate')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('transactionsSearch')), 'gérance');
    await tester.pumpAndSettle();
    expect(find.text('Gérance Imaginaire SA Rue du Bail 3 9999 Fictiville'), findsOneWidget);
    expect(find.text('Boulangerie des Tests Fictiville'), findsNothing);

    await tester.enterText(find.byKey(const Key('transactionsSearch')), '');
    await tester.pumpAndSettle();
    await write(
      tester,
      (l) => l.createRule('bread', const RuleDraft(year: 2026, keywords: ['boulangerie'], targetCategoryId: 'food')),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('filterStatus')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proposée').last);
    await tester.pumpAndSettle();
    expect(find.text('Boulangerie des Tests Fictiville'), findsNWidgets(3));
    expect(find.text('Gérance Imaginaire SA Rue du Bail 3 9999 Fictiville'), findsNothing);
  });

  testWidgets('the home screen lists lines whose rules compete and rules that propose nothing any more', (
    tester,
  ) async {
    await open(tester);
    await write(
      tester,
      (l) => l.createRule('a', const RuleDraft(year: 2026, keywords: ['épicerie'], targetCategoryId: 'food')),
    );
    await write(
      tester,
      (l) => l.createRule('b', const RuleDraft(year: 2026, keywords: ['coin'], targetCategoryId: 'rent')),
    );
    await write(
      tester,
      (l) => l.createRule('c', const RuleDraft(year: 2026, keywords: ['compte épargne'], targetAccountId: 'savings')),
    );
    await write(tester, (l) => l.removeAccount('savings').modification);
    await settle(tester);
    expect(find.text('5 lignes dont les règles sont en concurrence'), findsOneWidget);
    expect(find.text('Une règle de 2026 ne propose plus rien'), findsOneWidget);

    await tester.tap(find.byKey(const Key('taskConflicts')));
    await settle(tester);
    expect(find.textContaining('Règles en concurrence'), findsWidgets);
    await tester.tap(find.byType(BackButton).last);
    await settle(tester);
    await tester.tap(find.text('Une règle de 2026 ne propose plus rien'));
    await settle(tester);
    expect(find.textContaining('Cible inutilisable'), findsOneWidget);
  });
}
