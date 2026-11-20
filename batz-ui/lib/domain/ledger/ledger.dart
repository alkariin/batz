import '../journal/journal_entry.dart';
import 'account.dart';
import 'category.dart';
import 'ledger_exception.dart';
import 'transaction.dart';

/// Everything the user has entered, as read from the derived tables at one
/// moment. Immutable; the rules below check an operation against it and
/// return the [Modification] to write to the journal.
class Ledger {
  /// [categories] that do not form a consistent tree are left out (see
  /// [CategoryTree.build]).
  /// [lines] are attached to their transaction; a line whose transaction is
  /// absent is left out.
  Ledger({
    Iterable<Account> accounts = const [],
    Iterable<Category> categories = const [],
    Iterable<LedgerTransaction> transactions = const [],
    Iterable<TransactionLine> lines = const [],
  }) : accounts = {for (final a in accounts) a.id: a},
       trees = CategoryTree.build(categories),
       transactions = _attach(transactions, lines);

  static Map<String, LedgerTransaction> _attach(
    Iterable<LedgerTransaction> transactions,
    Iterable<TransactionLine> lines,
  ) {
    final byTransaction = <String, List<TransactionLine>>{};
    for (final line in lines) {
      (byTransaction[line.transactionId] ??= []).add(line);
    }
    return {
      for (final t in transactions)
        t.id: t.withLines([...t.lines, ...?byTransaction[t.id]]..sort((a, b) => a.id.compareTo(b.id))),
    };
  }

  static final empty = Ledger();

  final Map<String, Account> accounts;

  /// The category tree of each year that has one.
  final Map<int, CategoryTree> trees;

  final Map<String, LedgerTransaction> transactions;

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
  int transactionsUsingAccount(String accountId) =>
      transactions.values.where((t) => t.accountId == accountId || t.counterpartAccountId == accountId).length;

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
  int transactionsUsingCategory(String categoryId) =>
      transactions.values.where((t) => t.lines.any((line) => line.categoryId == categoryId)).length;

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

  // ------------------------------------------------------------ transactions

  /// Transactions by payment date, most recent first, optionally only those
  /// of [accountId] (as account or counterpart) and of [year].
  List<LedgerTransaction> transactionList({String? accountId, int? year}) {
    final list = [
      for (final t in transactions.values)
        if ((accountId == null || t.accountId == accountId || t.counterpartAccountId == accountId) &&
            (year == null || t.date.year == year))
          t,
    ];
    return list..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
  }

  /// Years that have transactions, in increasing order.
  List<int> get yearsWithTransactions => {for (final t in transactions.values) t.date.year}.toList()..sort();

  /// The type of [transaction], deduced from its counterpart, the nature of
  /// its category and its sign; null while it is not classified.
  TransactionKind? kindOf(LedgerTransaction transaction) {
    if (transaction.isTransfer) return TransactionKind.transfer;
    final category = categoryOf(transaction);
    if (category == null) return null;
    return switch (trees[category.year]!.natureOf(category.id)) {
      CategoryNature.income => TransactionKind.income,
      CategoryNature.expense => transaction.amount > 0 ? TransactionKind.refund : TransactionKind.expense,
    };
  }

  /// The category of the line of [transaction], if it is one of the tree of
  /// its payment year.
  Category? categoryOf(LedgerTransaction transaction) {
    final category = categories[transaction.line?.categoryId];
    return category != null && category.year == transaction.date.year ? category : null;
  }

  /// Records a manual expense or income, [id] with its line [lineId]. It is
  /// validated at once. If the year of the payment has no tree yet, the tree
  /// is created by the same modification (decision H6).
  Modification recordEntry(String id, String lineId, EntryDraft draft) {
    _checkManualAccount(draft.accountId, transfer: false);
    final changes = [
      ..._entryChanges(id, lineId, draft),
      FieldChange(TransactionFields.entity, id, TransactionFields.status, TransactionStatus.validated.name),
      FieldChange(TransactionFields.entity, id, TransactionFields.counterpartAccountId, null),
      ...treeChangesFor(draft.date.year),
    ];
    return Modification(changes);
  }

  /// Modifies the manual expense or income [id].
  Modification updateEntry(String id, EntryDraft draft) {
    final existing = _manualTransaction(id);
    if (existing.isTransfer) throw const LedgerException(LedgerError.unknownTransaction);
    _checkManualAccount(draft.accountId, transfer: false, allowArchived: draft.accountId == existing.accountId);
    return Modification([
      ..._entryChanges(id, existing.line?.id ?? fallbackLineId(id), draft),
      ...treeChangesFor(draft.date.year),
    ]);
  }

  /// The identifier of the line of a transaction that has lost its line.
  static String fallbackLineId(String transactionId) => '$transactionId-line';

  List<FieldChange> _entryChanges(String id, String lineId, EntryDraft draft) {
    if (draft.cents <= 0) throw const LedgerException(LedgerError.amountRequired);
    final tree = treeOrPreview(draft.date.year);
    if (!tree.canHoldTransactions(draft.categoryId)) throw const LedgerException(LedgerError.categoryNotAssignable);
    final start = draft.periodStart ?? draft.date;
    final end = draft.periodEnd ?? (draft.periodStart == null ? draft.date : start);
    if (end.isBefore(start)) throw const LedgerException(LedgerError.periodInvalid);
    final amount = signedAmount(draft.cents, draft.direction);
    return [
      for (final field in {
        TransactionFields.accountId: draft.accountId,
        TransactionFields.date: draft.date.encode(),
        TransactionFields.amount: amount,
        TransactionFields.description: draft.description.trim(),
        TransactionFields.note: draft.note.trim(),
      }.entries)
        FieldChange(TransactionFields.entity, id, field.key, field.value),
      for (final field in {
        LineFields.transactionId: id,
        LineFields.categoryId: draft.categoryId,
        LineFields.amount: amount,
        LineFields.periodStart: start.encode(),
        LineFields.periodEnd: end.encode(),
      }.entries)
        FieldChange(LineFields.entity, lineId, field.key, field.value),
    ];
  }

  /// Records a transfer: one transaction on the account the money leaves,
  /// with the receiving account as counterpart, and no category.
  Modification recordTransfer(String id, TransferDraft draft) {
    return Modification([
      ..._transferChanges(id, draft, previous: null),
      FieldChange(TransactionFields.entity, id, TransactionFields.status, TransactionStatus.validated.name),
    ]);
  }

  Modification updateTransfer(String id, TransferDraft draft) {
    final existing = _manualTransaction(id);
    if (!existing.isTransfer) throw const LedgerException(LedgerError.unknownTransaction);
    return Modification(_transferChanges(id, draft, previous: existing));
  }

  List<FieldChange> _transferChanges(String id, TransferDraft draft, {required LedgerTransaction? previous}) {
    if (draft.cents <= 0) throw const LedgerException(LedgerError.amountRequired);
    if (draft.fromAccountId == draft.toAccountId) throw const LedgerException(LedgerError.sameAccount);
    _checkManualAccount(draft.fromAccountId, transfer: true, allowArchived: draft.fromAccountId == previous?.accountId);
    _checkManualAccount(
      draft.toAccountId,
      transfer: true,
      allowArchived: draft.toAccountId == previous?.counterpartAccountId,
    );
    return [
      for (final field in {
        TransactionFields.accountId: draft.fromAccountId,
        TransactionFields.counterpartAccountId: draft.toAccountId,
        TransactionFields.date: draft.date.encode(),
        TransactionFields.amount: -draft.cents,
        TransactionFields.description: draft.description.trim(),
        TransactionFields.note: draft.note.trim(),
      }.entries)
        FieldChange(TransactionFields.entity, id, field.key, field.value),
      // A transfer has no category: a line left by an earlier version of the
      // transaction is deleted.
      for (final line in previous?.lines ?? const <TransactionLine>[])
        FieldChange(LineFields.entity, line.id, deletedField, true),
    ];
  }

  /// Deletes the manual transaction [id] and its lines.
  Modification deleteTransaction(String id) {
    final transaction = _manualTransaction(id);
    return Modification([
      FieldChange(TransactionFields.entity, id, deletedField, true),
      for (final line in transaction.lines) FieldChange(LineFields.entity, line.id, deletedField, true),
    ]);
  }

  /// A transaction the user may modify or delete: not on the detailed
  /// account, whose transactions come only from statements (4.3).
  LedgerTransaction _manualTransaction(String id) {
    final transaction = transactions[id];
    if (transaction == null) throw const LedgerException(LedgerError.unknownTransaction);
    if (accounts[transaction.accountId]?.isDetailed ?? false) {
      throw const LedgerException(LedgerError.detailedAccountManual);
    }
    return transaction;
  }

  /// Manual entries are refused on the detailed account (its transactions
  /// come only from statements) and, for expenses and incomes, on a debts
  /// account (changed only through the debts table). See docs/decisions.md.
  void _checkManualAccount(String accountId, {required bool transfer, bool allowArchived = false}) {
    final account = accounts[accountId];
    if (account == null) throw const LedgerException(LedgerError.unknownAccount);
    if (account.archived && !allowArchived) throw const LedgerException(LedgerError.archivedAccount);
    if (account.isDetailed) throw const LedgerException(LedgerError.detailedAccountManual);
    if (!transfer && account.type == AccountType.debts) throw const LedgerException(LedgerError.debtsAccountManual);
  }

  // ------------------------------------------------------------------ totals

  /// Cash-flow totals of [year], by category: every line of the transactions
  /// paid in [year], at its payment date. Transfers have no line and never
  /// count as income or expense.
  YearTotals cashTotals(int year) {
    final tree = trees[year];
    final byCategory = <String, int>{};
    var unclassified = 0;
    for (final transaction in transactions.values) {
      if (transaction.date.year != year || transaction.isTransfer) continue;
      for (final line in transaction.lines) {
        final categoryId = line.categoryId;
        if (tree == null || categoryId == null || !tree.byId.containsKey(categoryId)) {
          unclassified += line.amount;
          continue;
        }
        for (String? id = categoryId; id != null; id = tree.byId[id]!.parentId) {
          byCategory[id] = (byCategory[id] ?? 0) + line.amount;
        }
      }
    }
    int natureTotal(CategoryNature nature) => [
      for (final root in tree?.roots ?? const <Category>[])
        if (root.nature == nature) byCategory[root.id] ?? 0,
    ].fold(0, (a, b) => a + b);
    return YearTotals(
      year: year,
      byCategory: byCategory,
      income: natureTotal(CategoryNature.income),
      expenses: natureTotal(CategoryNature.expense),
      unclassified: unclassified,
    );
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
