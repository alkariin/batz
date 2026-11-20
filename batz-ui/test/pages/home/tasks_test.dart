import 'dart:async';

import 'package:batz/domain/journal/hlc.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/pages/ledger_cubit.dart';
import 'package:batz/pages/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../accounts/accounts_page_test.dart' show pumpApp, settle;

const _other = 'eeeeeeee-0000-4000-8000-000000000000';

void main() {
  testWidgets('without inconsistency, nothing to do', (tester) async {
    await pumpApp(tester);
    expect(find.text('À faire'), findsOneWidget);
    expect(find.text("Rien à faire pour l'instant."), findsOneWidget);
  });

  testWidgets('after a merge, each inconsistency is a task that leads to the screen that corrects it', (tester) async {
    final services = await pumpApp(tester);
    final year = DateTime.now().year;
    final expenses = defaultGroupId(year, CategoryNature.expense);
    await tester.runAsync(() async {
      var l = await services.ledger.load();
      await services.ledger.write(
        l.createAccount(
          'pf',
          const AccountDraft(
            name: 'PostFinance',
            type: AccountType.privateAccount,
            importFormat: ImportFormat.postfinance,
          ),
        ),
      );
      l = await services.ledger.load();
      await services.ledger.write(l.createTree(year));
      l = await services.ledger.load();
      await services.ledger.write(l.addCategory('food', year: year, name: 'Nourriture', parentId: expenses));
      l = await services.ledger.load();
      await services.ledger.write(l.addCategory('housing', year: year, name: 'Logement', parentId: expenses));
      l = await services.ledger.load();
      await services.ledger.write(l.addCategory('rent', year: year, name: 'Loyer', parentId: expenses));
      // What another device, used separately, brings.
      final t = DateTime.now().millisecondsSinceEpoch + 1000;
      var n = 0;
      JournalEntry e(String entity, String id, String field, Object? value) =>
          JournalEntry(Hlc(t, n++, _other), FieldChange(entity, id, field, value));
      await services.journal.merge([
        e('account', 'pf2', 'name', 'PostFinance 2'),
        e('account', 'pf2', 'type', 'privateAccount'),
        e('account', 'pf2', 'importFormat', 'postfinance'),
        e('category', 'food2', 'year', year),
        e('category', 'food2', 'name', 'nourriture'),
        e('category', 'food2', 'parentId', expenses),
        e('category', 'housing', 'parentId', 'rent'),
        e('category', 'rent', 'parentId', 'housing'),
      ]);
    });
    unawaited(tester.element(find.byType(AppShell)).read<LedgerCubit>().load());
    await settle(tester);

    expect(find.text('2 catégories « Nourriture » en $year'), findsOneWidget);
    expect(find.text('2 catégories à replacer en $year'), findsOneWidget);
    expect(find.text('2 comptes détaillés'), findsOneWidget);

    await tester.tap(find.text('2 catégories « Nourriture » en $year'));
    await tester.pumpAndSettle();
    expect(find.text('Nom en double dans cette année'), findsNWidgets(2));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2 comptes détaillés'));
    await tester.pumpAndSettle();
    expect(find.text('Compte privé · Détaillé'), findsNWidgets(2));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2 catégories à replacer en $year'));
    await tester.pumpAndSettle();
    expect(find.text('À replacer'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detachedMove-Logement')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(SimpleDialog), matching: find.text('Dépenses')));
    await settle(tester);
    expect(find.text('À replacer'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.textContaining('à replacer'), findsNothing);
    expect(find.text('2 comptes détaillés'), findsOneWidget);
  });
}
