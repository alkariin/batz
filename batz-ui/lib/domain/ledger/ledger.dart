import '../journal/journal_entry.dart';
import 'account.dart';
import 'category.dart';
import 'ledger_exception.dart';

/// Everything the user has entered, as read from the derived tables at one
/// moment. Immutable; the rules below check an operation against it and
/// return the [Modification] to write to the journal.
class Ledger {
  /// [categories] that do not form a consistent tree are left out (see
  /// [CategoryTree.build]).
  Ledger({Iterable<Account> accounts = const [], Iterable<Category> categories = const []})
    : accounts = {for (final a in accounts) a.id: a},
      trees = CategoryTree.build(categories);

  static final empty = Ledger();

  final Map<String, Account> accounts;

  /// The category tree of each year that has one.
  final Map<int, CategoryTree> trees;

  /// Every category of every year, by identifier.
  late final Map<String, Category> categories = {for (final tree in trees.values) ...tree.byId};

  /// Active accounts by name, then archived ones by name.
  List<Account> get sortedAccounts {
    int byName(Account a, Account b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return [
      ...accounts.values.where((a) => !a.archived).toList()..sort(byName),
      ...accounts.values.where((a) => a.archived).toList()..sort(byName),
    ];
  }

  // ---------------------------------------------------------------- accounts

  /// Creates the account [id]. Refused if the name is empty, or if import is
  /// enabled while another account is already detailed.
  Modification createAccount(String id, AccountDraft draft) {
    _checkAccount(id, draft);
    return Modification.set(AccountFields.entity, id, _accountFields(draft));
  }

  /// Modifies the account [id], under the same rules as [createAccount].
  Modification updateAccount(String id, AccountDraft draft) {
    if (!accounts.containsKey(id)) throw const LedgerException(LedgerError.unknownAccount);
    _checkAccount(id, draft);
    return Modification.set(AccountFields.entity, id, _accountFields(draft));
  }

  /// Removes the account [id] (decision H5 of phase 1): deleted if no
  /// transaction uses it, archived otherwise.
  AccountRemoval removeAccount(String id) {
    final account = accounts[id];
    if (account == null) throw const LedgerException(LedgerError.unknownAccount);
    final used = transactionsUsingAccount(id);
    if (used == 0) return AccountRemoval(Modification.delete(AccountFields.entity, id), 0);
    return AccountRemoval(Modification.set(AccountFields.entity, id, {AccountFields.archived: true}), used);
  }

  /// The number of transactions on [accountId] or with it as counterpart.
  int transactionsUsingAccount(String accountId) => 0;

  void _checkAccount(String id, AccountDraft draft) {
    if (draft.name.trim().isEmpty) throw const LedgerException(LedgerError.nameRequired);
    if (draft.importFormat != null && accounts.values.any((a) => a.id != id && a.isDetailed)) {
      throw const LedgerException(LedgerError.secondDetailedAccount);
    }
  }

  // -------------------------------------------------------------- categories

  /// Years that have a tree, in increasing order.
  List<int> get yearsWithTree => trees.keys.toList()..sort();

  /// The year whose tree [year] copies (decision H6): the closest earlier
  /// year that has one, or null if there is none.
  int? sourceYearFor(int year) {
    int? best;
    for (final candidate in trees.keys) {
      if (candidate < year && (best == null || candidate > best)) best = candidate;
    }
    return best;
  }

  /// The tree of [year] if it exists, otherwise the tree it would get from
  /// [createTree]: the transaction form offers its categories, and the copy
  /// is written with the first transaction of the year.
  CategoryTree treeOrPreview(int year) {
    final existing = trees[year];
    if (existing != null) return existing;
    final fields = <String, Map<String, Object?>>{};
    for (final change in _treeChanges(year)) {
      (fields[change.recordId] ??= {})[change.field] = change.value;
    }
    return CategoryTree.of(year, [
      for (final entry in fields.entries)
        Category(
          id: entry.key,
          year: year,
          name: entry.value[CategoryFields.name]! as String,
          parentId: entry.value[CategoryFields.parentId] as String?,
          nature: _nature(entry.value[CategoryFields.nature]),
          position: entry.value[CategoryFields.position]! as int,
        ),
    ]);
  }

  /// Creates the tree of [year]: a copy of the tree of [sourceYearFor], or,
  /// without one, the two empty groups « Revenus » and « Dépenses »
  /// (decisions H4 and H6). Copies get computed identifiers (design rule 4).
  Modification createTree(int year) {
    if (trees.containsKey(year)) throw const LedgerException(LedgerError.treeExists);
    return Modification(_treeChanges(year));
  }

  /// The changes that create the tree of [year], or none if it exists.
  List<FieldChange> treeChangesFor(int year) => trees.containsKey(year) ? const [] : _treeChanges(year);

  List<FieldChange> _treeChanges(int year) {
    final source = sourceYearFor(year);
    final changes = <FieldChange>[];
    void add(String id, Map<String, Object?> fields) {
      for (final field in fields.entries) {
        changes.add(FieldChange(CategoryFields.entity, id, field.key, field.value));
      }
    }

    if (source == null) {
      for (final (index, nature) in CategoryNature.values.indexed) {
        add(defaultGroupId(year, nature), {
          CategoryFields.year: year,
          CategoryFields.name: defaultGroupNames[nature],
          CategoryFields.parentId: null,
          CategoryFields.nature: nature.name,
          CategoryFields.position: index,
        });
      }
      return changes;
    }
    for (final category in trees[source]!.ordered) {
      add(copiedCategoryId(category.id, year), {
        CategoryFields.year: year,
        CategoryFields.name: category.name,
        CategoryFields.parentId: category.parentId == null ? null : copiedCategoryId(category.parentId!, year),
        CategoryFields.nature: category.isTopLevel ? category.nature!.name : null,
        CategoryFields.position: category.position,
      });
    }
    return changes;
  }

  /// Adds the category [id] to the tree of [year], under [parentId], or as a
  /// top-level group of [nature] when [parentId] is null. Refused if the name
  /// is already used in the year (decision H1) or if the parent holds
  /// transactions (decision H2).
  Modification addCategory(
    String id, {
    required int year,
    required String name,
    String? parentId,
    CategoryNature? nature,
  }) {
    final tree = trees[year];
    if (tree == null) throw const LedgerException(LedgerError.noTree);
    _checkName(tree, name, exceptId: null);
    if (parentId == null) {
      if (nature == null) throw const LedgerException(LedgerError.natureRequired);
    } else {
      _checkParent(tree, parentId);
    }
    final siblings = parentId == null ? tree.roots : tree.childrenOf(parentId);
    return Modification.set(CategoryFields.entity, id, {
      CategoryFields.year: year,
      CategoryFields.name: name.trim(),
      CategoryFields.parentId: parentId,
      CategoryFields.nature: parentId == null ? nature!.name : null,
      CategoryFields.position: _nextPosition(siblings),
    });
  }

  Modification renameCategory(String id, String name) {
    final category = _category(id);
    _checkName(trees[category.year]!, name, exceptId: id);
    return Modification.set(CategoryFields.entity, id, {CategoryFields.name: name.trim()});
  }

  /// Moves [id] under [parentId], or to the top level with [nature] when
  /// [parentId] is null. Refused if it would create a loop, or if the new
  /// parent holds transactions (decision H2). The category goes last among
  /// its new siblings.
  Modification moveCategory(String id, {String? parentId, CategoryNature? nature}) {
    final category = _category(id);
    final tree = trees[category.year]!;
    if (parentId == null) {
      if (nature == null) throw const LedgerException(LedgerError.natureRequired);
    } else {
      if (tree.subtreeOf(id).contains(parentId)) throw const LedgerException(LedgerError.categoryLoop);
      _checkParent(tree, parentId);
    }
    final siblings = (parentId == null ? tree.roots : tree.childrenOf(parentId)).where((c) => c.id != id);
    return Modification.set(CategoryFields.entity, id, {
      CategoryFields.parentId: parentId,
      CategoryFields.nature: parentId == null ? nature!.name : null,
      CategoryFields.position: _nextPosition(siblings),
    });
  }

  /// Moves [id] one place up ([offset] -1) or down (+1) among its siblings.
  /// Returns null if it is already first or last.
  Modification? reorderCategory(String id, int offset) {
    final category = _category(id);
    final tree = trees[category.year]!;
    final siblings = [...(category.parentId == null ? tree.roots : tree.childrenOf(category.parentId!))];
    final from = siblings.indexWhere((c) => c.id == id);
    final to = from + offset;
    if (to < 0 || to >= siblings.length) return null;
    siblings.insert(to, siblings.removeAt(from));
    // Positions are renumbered so that equal positions (after a merge) still
    // give a definite order.
    final changes = [
      for (final (index, sibling) in siblings.indexed)
        if (sibling.position != index) FieldChange(CategoryFields.entity, sibling.id, CategoryFields.position, index),
    ];
    return changes.isEmpty ? null : Modification(changes);
  }

  /// Deletes [id] (decision H5): refused while it has children, or while
  /// transactions use it, with their number.
  Modification removeCategory(String id) {
    final category = _category(id);
    if (trees[category.year]!.hasChildren(id)) throw const LedgerException(LedgerError.categoryHasChildren);
    final used = transactionsUsingCategory(id);
    if (used > 0) throw LedgerException(LedgerError.categoryInUse, count: used);
    return Modification.delete(CategoryFields.entity, id);
  }

  /// The number of transactions classified in [categoryId].
  int transactionsUsingCategory(String categoryId) => 0;

  Category _category(String id) {
    final category = categories[id];
    if (category == null) throw const LedgerException(LedgerError.unknownCategory);
    return category;
  }

  void _checkName(CategoryTree tree, String name, {required String? exceptId}) {
    if (name.trim().isEmpty) throw const LedgerException(LedgerError.nameRequired);
    final existing = tree.named(name);
    if (existing != null && existing.id != exceptId) throw const LedgerException(LedgerError.categoryNameTaken);
  }

  void _checkParent(CategoryTree tree, String parentId) {
    if (!tree.byId.containsKey(parentId)) throw const LedgerException(LedgerError.unknownCategory);
    final used = transactionsUsingCategory(parentId);
    if (used > 0) throw LedgerException(LedgerError.parentHasTransactions, count: used);
  }

  static int _nextPosition(Iterable<Category> siblings) =>
      siblings.fold(-1, (max, c) => c.position > max ? c.position : max) + 1;

  static CategoryNature? _nature(Object? name) => switch (name) {
    'income' => CategoryNature.income,
    'expense' => CategoryNature.expense,
    _ => null,
  };

  static Map<String, Object?> _accountFields(AccountDraft draft) => {
    AccountFields.name: draft.name.trim(),
    AccountFields.type: draft.type.name,
    AccountFields.importFormat: draft.importFormat?.name,
    AccountFields.archived: draft.archived,
  };
}

/// The outcome of [Ledger.removeAccount].
class AccountRemoval {
  const AccountRemoval(this.modification, this.transactionCount);

  final Modification modification;

  /// Transactions that use the account; when there are any, the account is
  /// archived instead of deleted.
  final int transactionCount;

  bool get archives => transactionCount > 0;
}
