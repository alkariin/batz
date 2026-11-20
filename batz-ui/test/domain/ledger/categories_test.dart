import 'dart:math';

import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher refusedWith(LedgerError error) => throwsA(isA<LedgerException>().having((e) => e.error, 'error', error));

/// Applies [m] to the categories of [ledger], as the journal would.
Ledger apply(Ledger ledger, Modification m) {
  final fields = {
    for (final c in ledger.categories.values)
      c.id: <String, Object?>{
        'year': c.year,
        'name': c.name,
        'parentId': c.parentId,
        'nature': c.nature?.name,
        'position': c.position,
      },
  };
  final deleted = <String>{};
  for (final change in m.changes) {
    if (change.field == deletedField) {
      if (change.value == true) deleted.add(change.recordId);
      continue;
    }
    (fields[change.recordId] ??= {})[change.field] = change.value;
  }
  return Ledger(
    accounts: ledger.accounts.values,
    categories: [
      for (final e in fields.entries)
        if (!deleted.contains(e.key))
          Category(
            id: e.key,
            year: e.value['year']! as int,
            name: e.value['name']! as String,
            parentId: e.value['parentId'] as String?,
            nature: CategoryNature.values.where((n) => n.name == e.value['nature']).firstOrNull,
            position: (e.value['position'] as int?) ?? 0,
          ),
    ],
  );
}

final expenses2026 = defaultGroupId(2026, CategoryNature.expense);
final income2026 = defaultGroupId(2026, CategoryNature.income);

/// 2026: Revenus > Salaire; Dépenses > Logement > Loyer, Dépenses > Impôts.
Ledger sample() {
  var l = apply(Ledger.empty, Ledger.empty.createTree(2026));
  l = apply(l, l.addCategory('salary', year: 2026, name: 'Salaire', parentId: income2026));
  l = apply(l, l.addCategory('housing', year: 2026, name: 'Logement', parentId: expenses2026));
  l = apply(l, l.addCategory('rent', year: 2026, name: 'Loyer', parentId: 'housing'));
  l = apply(l, l.addCategory('taxes', year: 2026, name: 'Impôts', parentId: expenses2026));
  return l;
}

List<String> names(CategoryTree tree) => [for (final c in tree.ordered) '${'  ' * tree.depthOf(c.id)}${c.name}'];

void main() {
  group('names (H1)', () {
    test('compare without case, accents or surrounding spaces', () {
      expect(normalizeName('Impôts'), normalizeName(' impots '));
      expect(normalizeName('ÉLECTRICITÉ'), 'electricite');
      expect(normalizeName('Cœur'), 'coeur');
      expect(normalizeName('Straße'), 'strasse');
      expect(normalizeName('Ski  alpin'), isNot(normalizeName('Ski alpin')), reason: 'only spaces around count');
    });

    test('two categories with the same name in one year are refused', () {
      final l = sample();
      for (final name in ['Impôts', 'impots', '  IMPOTS ', 'Impóts']) {
        expect(
          () => l.addCategory('x', year: 2026, name: name, parentId: 'housing'),
          refusedWith(LedgerError.categoryNameTaken),
          reason: name,
        );
      }
      expect(() => l.renameCategory('rent', 'logement'), refusedWith(LedgerError.categoryNameTaken));
      expect(
        () => l.addCategory('x', year: 2026, name: 'dépenses', parentId: 'housing'),
        refusedWith(LedgerError.categoryNameTaken),
        reason: 'groups count too',
      );
      // Renaming a category to a variant of its own name is fine.
      expect(l.renameCategory('taxes', 'impôts').changes.single.value, 'impôts');
    });

    test('the same name in another year is fine', () {
      var l = sample();
      l = apply(l, l.createTree(2027));
      final m = l.addCategory('x', year: 2027, name: 'Vacances', parentId: copiedCategoryId(expenses2026, 2027));
      l = apply(l, m);
      expect(l.addCategory('y', year: 2026, name: 'Vacances', parentId: expenses2026).changes, isNotEmpty);
    });

    test('an empty name is refused', () {
      expect(
        () => sample().addCategory('x', year: 2026, name: ' ', parentId: 'housing'),
        refusedWith(LedgerError.nameRequired),
      );
    });
  });

  group('trees (H4, H6, rule 4)', () {
    test('the first tree starts from two empty groups', () {
      final l = apply(Ledger.empty, Ledger.empty.createTree(2026));
      final tree = l.trees[2026]!;
      expect(names(tree), ['Revenus', 'Dépenses']);
      expect(tree.roots.map((c) => c.id), [income2026, expenses2026]);
      expect(tree.natureOf(income2026), CategoryNature.income);
      expect(tree.natureOf(expenses2026), CategoryNature.expense);
    });

    test('a tree cannot be created twice', () {
      expect(() => sample().createTree(2026), refusedWith(LedgerError.treeExists));
    });

    test('a year copies the closest earlier year that has a tree', () {
      var l = sample();
      expect(l.sourceYearFor(2026), isNull);
      expect(l.sourceYearFor(2030), 2026);
      l = apply(l, l.createTree(2028));
      l = apply(l, l.renameCategory(copiedCategoryId('rent', 2028), 'Loyer 2028'));
      expect(l.sourceYearFor(2027), 2026);
      expect(l.sourceYearFor(2029), 2028);
      l = apply(l, l.createTree(2029));
      expect(l.trees[2029]!.named('Loyer 2028'), isNotNull);
      l = apply(l, l.createTree(2027));
      expect(l.trees[2027]!.named('Loyer'), isNotNull);
      // A year before every tree starts again from the two groups.
      l = apply(l, l.createTree(2025));
      expect(names(l.trees[2025]!), ['Revenus', 'Dépenses']);
    });

    test('a copy keeps the structure, with identifiers computed from the source and the year', () {
      var l = sample();
      final m = l.createTree(2027);
      l = apply(l, m);
      expect(names(l.trees[2027]!), names(l.trees[2026]!));
      expect(l.trees[2027]!.byId.keys.toSet(), {for (final id in l.trees[2026]!.byId.keys) copiedCategoryId(id, 2027)});
      expect(l.categories[copiedCategoryId('rent', 2027)]!.parentId, copiedCategoryId('housing', 2027));
      // The same copy computed again, as another device would: same changes.
      expect(sample().createTree(2027).changes.map((c) => '$c'), m.changes.map((c) => '$c'));
      expect(copiedCategoryId('rent', 2027), isNot(copiedCategoryId('rent', 2028)));
      expect(
        copiedCategoryId('rent', 2027),
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
      );
    });

    test('changing the copy leaves the previous year untouched', () {
      var l = sample();
      l = apply(l, l.createTree(2027));
      l = apply(l, l.renameCategory(copiedCategoryId('rent', 2027), 'Loyer et charges'));
      l = apply(l, l.removeCategory(copiedCategoryId('taxes', 2027)));
      expect(names(l.trees[2026]!), ['Revenus', '  Salaire', 'Dépenses', '  Logement', '    Loyer', '  Impôts']);
      expect(names(l.trees[2027]!), ['Revenus', '  Salaire', 'Dépenses', '  Logement', '    Loyer et charges']);
    });

    test('the preview of a year without a tree is the tree it will get', () {
      final l = sample();
      final preview = l.treeOrPreview(2027);
      final created = apply(l, l.createTree(2027)).trees[2027]!;
      expect(preview.byId, created.byId);
      expect(l.treeOrPreview(2026), same(l.trees[2026]));
      expect(l.treeChangesFor(2026), isEmpty);
      expect(l.treeChangesFor(2027).map((c) => '$c'), l.createTree(2027).changes.map((c) => '$c'));
    });
  });

  group('structure', () {
    test('the nature is inherited from the top-level group', () {
      final tree = sample().trees[2026]!;
      expect(tree.natureOf('rent'), CategoryNature.expense);
      expect(tree.natureOf('salary'), CategoryNature.income);
      expect(tree.rootOf('rent').id, expenses2026);
    });

    test('only categories without children, below a group, hold transactions (H2)', () {
      final tree = sample().trees[2026]!;
      expect(tree.canHoldTransactions('rent'), isTrue);
      expect(tree.canHoldTransactions('taxes'), isTrue);
      expect(tree.canHoldTransactions('housing'), isFalse);
      expect(tree.canHoldTransactions(expenses2026), isFalse);
      expect(tree.assignable.map((c) => c.name), ['Salaire', 'Loyer', 'Impôts']);
    });

    test('a new top-level group needs a nature', () {
      final l = sample();
      expect(() => l.addCategory('x', year: 2026, name: 'Divers'), refusedWith(LedgerError.natureRequired));
      final added = apply(l, l.addCategory('x', year: 2026, name: 'Divers', nature: CategoryNature.expense));
      expect(names(added.trees[2026]!).last, 'Divers');
      expect(
        () => l.addCategory('x', year: 2027, name: 'Divers', nature: CategoryNature.expense),
        refusedWith(LedgerError.noTree),
      );
    });

    test('a move cannot create a loop', () {
      final l = sample();
      expect(() => l.moveCategory('housing', parentId: 'rent'), refusedWith(LedgerError.categoryLoop));
      expect(() => l.moveCategory('housing', parentId: 'housing'), refusedWith(LedgerError.categoryLoop));
      expect(() => l.moveCategory(expenses2026, parentId: 'rent'), refusedWith(LedgerError.categoryLoop));
    });

    test('a move takes the category and its children, last among the new siblings', () {
      var l = sample();
      l = apply(l, l.moveCategory('housing', parentId: 'taxes'));
      expect(names(l.trees[2026]!), ['Revenus', '  Salaire', 'Dépenses', '  Impôts', '    Logement', '      Loyer']);
      l = apply(l, l.moveCategory('housing', nature: CategoryNature.expense));
      expect(names(l.trees[2026]!).last, '  Loyer');
      expect(l.trees[2026]!.natureOf('rent'), CategoryNature.expense);
      expect(() => l.moveCategory('rent'), refusedWith(LedgerError.natureRequired));
      // A group moved below another one takes its nature.
      l = apply(l, l.moveCategory('housing', parentId: income2026));
      expect(l.trees[2026]!.natureOf('rent'), CategoryNature.income);
    });

    test('siblings are reordered', () {
      var l = sample();
      expect(l.reorderCategory('housing', -1), isNull, reason: 'already first');
      l = apply(l, l.reorderCategory('housing', 1)!);
      expect(names(l.trees[2026]!), ['Revenus', '  Salaire', 'Dépenses', '  Impôts', '  Logement', '    Loyer']);
      expect(l.reorderCategory('housing', 1), isNull, reason: 'already last');
      l = apply(l, l.reorderCategory(expenses2026, -1)!);
      expect(names(l.trees[2026]!).first, 'Dépenses');
    });

    test('equal positions, as after a merge, still reorder', () {
      var l = sample();
      l = apply(l, Modification([FieldChange('category', 'taxes', 'position', 0)]));
      final first = l.trees[2026]!.childrenOf(expenses2026).first.id;
      l = apply(l, l.reorderCategory(first, 1)!);
      expect(l.trees[2026]!.childrenOf(expenses2026).last.id, first);
    });

    test('a category with children cannot be deleted', () {
      final l = sample();
      expect(() => l.removeCategory('housing'), refusedWith(LedgerError.categoryHasChildren));
      expect(apply(l, l.removeCategory('rent')).categories.containsKey('rent'), isFalse);
      expect(() => l.removeCategory('nope'), refusedWith(LedgerError.unknownCategory));
    });
  });

  group('incomplete records are ignored (rule 2)', () {
    test('missing parent, other year, loop, group without nature', () {
      final l = Ledger(
        categories: [
          const Category(id: 'g', year: 2026, name: 'Dépenses', nature: CategoryNature.expense),
          const Category(id: 'ok', year: 2026, name: 'Loyer', parentId: 'g'),
          const Category(id: 'orphan', year: 2026, name: 'Orphelin', parentId: 'not-yet-arrived'),
          const Category(id: 'below-orphan', year: 2026, name: 'Sous orphelin', parentId: 'orphan'),
          const Category(id: 'other-year', year: 2027, name: 'Autre année', parentId: 'g'),
          const Category(id: 'loop-a', year: 2026, name: 'A', parentId: 'loop-b'),
          const Category(id: 'loop-b', year: 2026, name: 'B', parentId: 'loop-a'),
          const Category(id: 'no-nature', year: 2026, name: 'Sans nature'),
          const Category(id: 'below-no-nature', year: 2026, name: 'Dessous', parentId: 'no-nature'),
        ],
      );
      expect(l.categories.keys.toSet(), {'g', 'ok'});
      expect(l.trees.keys, [2026]);
    });
  });

  group('detached categories (phase 2, H4)', () {
    Ledger detachedSample() => Ledger(
      categories: [
        const Category(id: 'g', year: 2026, name: 'Dépenses', nature: CategoryNature.expense),
        const Category(id: 'ok', year: 2026, name: 'Loyer', parentId: 'g'),
        const Category(id: 'orphan', year: 2026, name: 'Orphelin', parentId: 'deleted-parent'),
        const Category(id: 'below-orphan', year: 2026, name: 'Sous orphelin', parentId: 'orphan'),
        const Category(id: 'deep', year: 2026, name: 'Tout en bas', parentId: 'below-orphan'),
        const Category(id: 'other-year', year: 2027, name: 'Autre année', parentId: 'g'),
        const Category(id: 'loop-a', year: 2026, name: 'A', parentId: 'loop-b'),
        const Category(id: 'loop-b', year: 2026, name: 'B', parentId: 'loop-a'),
        const Category(id: 'into-loop', year: 2026, name: 'Vers la boucle', parentId: 'loop-a'),
        const Category(id: 'self', year: 2026, name: 'Soi', parentId: 'self'),
        const Category(id: 'no-nature', year: 2026, name: 'Sans nature'),
        const Category(id: 'below-no-nature', year: 2026, name: 'Dessous', parentId: 'no-nature'),
      ],
    );

    test('each detached category has its reason; none is lost', () {
      final l = detachedSample();
      final reasons = {for (final d in l.forest.detached.values) d.category.id: d.reason};
      expect(reasons, {
        'orphan': DetachReason.missingParent,
        'below-orphan': DetachReason.detachedAncestor,
        'deep': DetachReason.detachedAncestor,
        'other-year': DetachReason.parentInOtherYear,
        'loop-a': DetachReason.loop,
        'loop-b': DetachReason.loop,
        'into-loop': DetachReason.detachedAncestor,
        'self': DetachReason.loop,
        'no-nature': DetachReason.groupWithoutNature,
        'below-no-nature': DetachReason.detachedAncestor,
      });
      expect(l.categories.length + l.forest.detached.length, 12);
    });

    test('the result does not depend on the order of the categories', () {
      final categories = [...detachedSample().forest.detached.values.map((d) => d.category)];
      final attached = detachedSample().categories.values;
      final expected = detachedSample().forest.detached;
      for (var seed = 0; seed < 20; seed++) {
        final shuffled = [...categories, ...attached]..shuffle(Random(seed));
        expect(Ledger(categories: shuffled).forest.detached, expected, reason: 'seed $seed');
      }
    });

    test('heads are listed per year, the categories below them follow', () {
      final forest = detachedSample().forest;
      expect(forest.yearsWithDetached, [2026, 2027]);
      expect(forest.detachedHeads(2026).map((d) => d.category.name), ['A', 'B', 'Orphelin', 'Sans nature', 'Soi']);
      expect(forest.detachedHeads(2027).map((d) => d.category.id), ['other-year']);
      expect(forest.detachedChildrenOf('orphan').map((c) => c.id), ['below-orphan']);
      expect(forest.detachedChildrenOf('below-orphan').map((c) => c.id), ['deep']);
      expect(forest.detachedChildrenOf('loop-a').map((c) => c.id), ['into-loop'], reason: 'loop members are heads');
    });

    test('a detached category is put back by a move, with what is below it', () {
      var l = detachedSample();
      l = applyAll(l, l.moveCategory('orphan', parentId: 'g'));
      expect(l.trees[2026]!.byId.keys, containsAll(['orphan', 'below-orphan', 'deep']));
      expect(l.trees[2026]!.depthOf('deep'), 3);

      l = applyAll(l, l.moveCategory('loop-a', nature: CategoryNature.income));
      expect(l.trees[2026]!.byId.keys, containsAll(['loop-a', 'loop-b', 'into-loop']));
      expect(l.trees[2026]!.natureOf('loop-b'), CategoryNature.income);

      // A group without nature only needs one.
      final m = l.moveCategory('no-nature', nature: CategoryNature.expense);
      expect(m.changes.map((c) => c.field), containsAll(['nature', 'position']));
      l = applyAll(l, m);
      expect(l.trees[2026]!.byId.keys, containsAll(['no-nature', 'below-no-nature']));

      // A year without any tree: to the top level only.
      expect(() => l.moveCategory('other-year', parentId: 'g'), refusedWith(LedgerError.unknownCategory));
      l = applyAll(l, l.moveCategory('other-year', nature: CategoryNature.expense));
      expect(l.trees[2027]!.byId.keys, ['other-year']);

      // Its own parent.
      l = applyAll(l, l.moveCategory('self', parentId: 'g'));
      expect(l.forest.detached, isEmpty);
    });

    test('a detached category cannot go under another detached one', () {
      final l = detachedSample();
      expect(() => l.moveCategory('orphan', parentId: 'loop-a'), refusedWith(LedgerError.unknownCategory));
    });
  });
}

/// Applies [m] to every category of [ledger], detached ones included.
Ledger applyAll(Ledger ledger, Modification m) {
  final byId = {
    for (final c in [...ledger.categories.values, ...ledger.forest.detached.values.map((d) => d.category)]) c.id: c,
  };
  final fields = {
    for (final c in byId.values)
      c.id: <String, Object?>{
        'year': c.year,
        'name': c.name,
        'parentId': c.parentId,
        'nature': c.nature?.name,
        'position': c.position,
      },
  };
  for (final change in m.changes) {
    (fields[change.recordId] ??= {})[change.field] = change.value;
  }
  return Ledger(
    categories: [
      for (final e in fields.entries)
        Category(
          id: e.key,
          year: e.value['year']! as int,
          name: e.value['name']! as String,
          parentId: e.value['parentId'] as String?,
          nature: CategoryNature.values.where((n) => n.name == e.value['nature']).firstOrNull,
          position: (e.value['position'] as int?) ?? 0,
        ),
    ],
  );
}
