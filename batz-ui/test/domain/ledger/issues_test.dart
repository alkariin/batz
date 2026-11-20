import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/issues.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import 'categories_test.dart' show expenses2026, income2026, refusedWith, sample;

const _g = Category(id: 'g', year: 2026, name: 'Dépenses', nature: CategoryNature.expense);

void main() {
  test('a consistent ledger has no issue', () {
    expect(sample().issues, isEmpty);
  });

  test('two categories of one year with the same name, compared as names are (H1 of phase 1)', () {
    final l = Ledger(
      categories: [
        _g,
        const Category(id: 'a', year: 2026, name: 'Impôts', parentId: 'g'),
        const Category(id: 'b', year: 2026, name: ' impots ', parentId: 'g', position: 1),
        const Category(id: 'c', year: 2026, name: 'Loyer', parentId: 'g'),
        const Category(id: 'g27', year: 2027, name: 'Dépenses', nature: CategoryNature.expense),
        const Category(id: 'd', year: 2027, name: 'Impôts', parentId: 'g27'),
      ],
    );
    expect(l.issues, [
      DuplicateCategoryName(2026, [l.categories['a']!, l.categories['b']!]),
    ], reason: 'the same name in another year is fine');
    expect((l.issues.single as DuplicateCategoryName).name, 'Impôts');
  });

  test('several detailed accounts, archived ones included', () {
    final l = Ledger(
      accounts: const [
        Account(
          id: 'pf',
          name: 'PostFinance',
          type: AccountType.privateAccount,
          importFormat: ImportFormat.postfinance,
        ),
        Account(
          id: 'old',
          name: 'Ancien',
          type: AccountType.privateAccount,
          importFormat: ImportFormat.postfinance,
          archived: true,
        ),
        Account(id: 'cash', name: 'Espèces', type: AccountType.cash),
      ],
    );
    expect(l.issues, [
      SeveralDetailedAccounts([l.accounts['pf']!, l.accounts['old']!]),
    ]);

    // Never blocking: a detailed account stays editable, and disabling the
    // import on one solves it; a third one is still refused.
    expect(
      l
          .updateAccount(
            'pf',
            const AccountDraft(name: 'PF', type: AccountType.privateAccount, importFormat: ImportFormat.postfinance),
          )
          .changes,
      isNotEmpty,
    );
    expect(
      () => l.updateAccount(
        'cash',
        const AccountDraft(name: 'Espèces', type: AccountType.cash, importFormat: ImportFormat.postfinance),
      ),
      refusedWith(LedgerError.secondDetailedAccount),
    );
    final fixed = Ledger(
      accounts: [
        l.accounts['pf']!,
        const Account(id: 'old', name: 'Ancien', type: AccountType.privateAccount, archived: true),
        l.accounts['cash']!,
      ],
    );
    expect(fixed.issues, isEmpty);
  });

  test('detached categories, per year, with their heads', () {
    final l = Ledger(
      categories: [
        _g,
        const Category(id: 'a', year: 2026, name: 'A', parentId: 'b'),
        const Category(id: 'b', year: 2026, name: 'B', parentId: 'a'),
        const Category(id: 'orphan', year: 2027, name: 'Orphelin', parentId: 'gone'),
      ],
    );
    expect(l.issues.map((i) => (i as DetachedCategories).year), [2026, 2027]);
    expect((l.issues.first as DetachedCategories).heads.map((d) => d.category.id), ['a', 'b']);
  });

  test('issues come by year, then accounts', () {
    final l = Ledger(
      accounts: const [
        Account(id: 'x', name: 'X', type: AccountType.other, importFormat: ImportFormat.postfinance),
        Account(id: 'y', name: 'Y', type: AccountType.other, importFormat: ImportFormat.postfinance),
      ],
      categories: [
        _g,
        const Category(id: 'a', year: 2026, name: 'Loyer', parentId: 'g'),
        const Category(id: 'b', year: 2026, name: 'loyer', parentId: 'g'),
        const Category(id: 'c', year: 2026, name: 'C', parentId: 'missing'),
      ],
    );
    expect(l.issues.map((i) => i.runtimeType), [DuplicateCategoryName, DetachedCategories, SeveralDetailedAccounts]);
  });

  test('the default groups never count as duplicates', () {
    expect(Ledger(categories: [for (final c in sample().categories.values) c]).issues, isEmpty);
    expect(income2026, isNot(expenses2026));
  });
}
