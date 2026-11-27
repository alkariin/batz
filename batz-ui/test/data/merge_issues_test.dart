import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/issues.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ledger_harness.dart';
import 'categories_sync_test.dart' show deviceA, deviceB;

void main() {
  test(
    'two devices used separately, merged: duplicates are detected, then corrected with the usual operations',
    () async {
      var wallA = 1000, wallB = 2000;
      final a = await LedgerHarness.open(deviceId: deviceA, now: () => wallA);
      final b = await LedgerHarness.open(deviceId: deviceB, now: () => wallB);
      final expenses = defaultGroupId(2026, CategoryNature.expense);
      for (final (h, account) in [(a, 'pf-a'), (b, 'pf-b')]) {
        await h.apply(
          (l) => l.createAccount(
            account,
            const AccountDraft(
              name: 'PostFinance',
              type: AccountType.privateAccount,
              importFormat: ImportFormat.postfinance,
            ),
          ),
        );
        await h.apply((l) => l.createTree(2026));
        await h.apply((l) => l.addCategory('food-$account', year: 2026, name: 'Nourriture', parentId: expenses));
      }
      final fromA = await a.journal.entries(), fromB = await b.journal.entries();
      await a.journal.merge(fromB);
      await b.journal.merge(fromA);

      var ledger = await a.ledger();
      expect(
        ledger.trees[2026]!.ordered.where((c) => c.name == 'Revenus'),
        hasLength(1),
        reason: 'computed identifiers',
      );
      expect(ledger.issues, [
        DuplicateCategoryName(2026, [ledger.categories['food-pf-a']!, ledger.categories['food-pf-b']!]),
      ]);

      wallA = 5000;
      await a.apply((l) => l.renameCategory('food-pf-b', 'Nourriture (B)'));
      await a.apply(
        (l) => l.updateAccount('pf-b', const AccountDraft(name: 'PostFinance B', type: AccountType.privateAccount)),
      );
      ledger = await a.ledger();
      expect(ledger.issues, isEmpty);
      await b.journal.merge(await a.journal.entries());
      expect((await b.ledger()).issues, isEmpty);
      await a.close();
      await b.close();
    },
  );
}
