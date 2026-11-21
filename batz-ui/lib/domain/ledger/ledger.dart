import '../calendar_date.dart';
import '../journal/journal_entry.dart';
import '../period_model.dart';
import 'account.dart';
import 'category.dart';
import 'issues.dart';
import 'ledger_exception.dart';
import 'proposal.dart';
import 'redistribution.dart';
import 'rule.dart';
import 'statement.dart';
import 'transaction.dart';

/// Everything the user has entered, as read from the derived tables at one
/// moment. Immutable; the rules below check an operation against it and
/// return the [Modification] to write to the journal.
class Ledger {
  /// [categories] that do not form a consistent tree are kept apart, as
  /// detached categories (see [CategoryForest.build]).
  /// [lines] are attached to their transaction; a line whose transaction is
  /// absent is left out.
  /// [deletedStatementIds] are the statements deleted from the journal: one
  /// imported again must bring its records back explicitly.
  Ledger({
    Iterable<Account> accounts = const [],
    Iterable<Category> categories = const [],
    Iterable<LedgerTransaction> transactions = const [],
    Iterable<TransactionLine> lines = const [],
    Iterable<Statement> statements = const [],
    Iterable<String> deletedStatementIds = const [],
    Iterable<MappingRule> rules = const [],
    Iterable<RedistributionRule> redistributions = const [],
  }) : this._(
         accounts,
         CategoryForest.build(categories),
         transactions,
         lines,
         statements,
         deletedStatementIds,
         rules,
         redistributions,
       );

  Ledger._(
    Iterable<Account> accounts,
    this.forest,
    Iterable<LedgerTransaction> transactions,
    Iterable<TransactionLine> lines,
    Iterable<Statement> statements,
    Iterable<String> deletedStatementIds,
    Iterable<MappingRule> rules,
    Iterable<RedistributionRule> redistributions,
  ) : accounts = {for (final a in accounts) a.id: a},
      trees = forest.trees,
      transactions = _attach(transactions, lines),
      statements = {for (final s in statements) s.id: s},
      deletedStatementIds = Set.unmodifiable(deletedStatementIds),
      rules = {for (final r in rules) r.id: r},
      redistributions = {for (final r in redistributions) r.id: r};

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

  /// The trees and the detached categories, which belong to no tree.
  final CategoryForest forest;

  final Map<String, LedgerTransaction> transactions;

  final Map<String, Statement> statements;
  final Set<String> deletedStatementIds;

  /// The mapping rules of every year, by identifier.
  final Map<String, MappingRule> rules;

  /// The redistribution rules of every year, by identifier (see
  /// redistribution.dart for their operations).
  final Map<String, RedistributionRule> redistributions;

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

  // ------------------------------------------------------------------ issues

  /// The inconsistencies of decision H4 of phase 2, by year, then accounts:
  /// categories with the same name in one year, several detailed accounts,
  /// detached categories.
  late final List<LedgerIssue> issues = () {
    final result = <LedgerIssue>[];
    final years = {...trees.keys, ...forest.yearsWithDetached}.toList()..sort();
    for (final year in years) {
      final tree = trees[year];
      if (tree != null) {
        final byName = <String, List<Category>>{};
        for (final category in tree.ordered) {
          (byName[normalizeName(category.name)] ??= []).add(category);
        }
        for (final same in byName.values) {
          if (same.length > 1) result.add(DuplicateCategoryName(year, same));
        }
      }
      final heads = forest.detachedHeads(year);
      if (heads.isNotEmpty) result.add(DetachedCategories(year, heads));
    }
    final detailed = sortedAccounts.where((a) => a.isDetailed).toList();
    if (detailed.length > 1) result.add(SeveralDetailedAccounts(detailed));
    return result;
  }();

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

  /// A second detailed account is refused. An account that already is one
  /// stays editable even when a merge left another detailed account
  /// (decision H4 of phase 2: never blocking).
  void _checkAccount(String id, AccountDraft draft) {
    if (draft.name.trim().isEmpty) throw const LedgerException(LedgerError.nameRequired);
    final alreadyDetailed = accounts[id]?.isDetailed ?? false;
    if (draft.importFormat != null && !alreadyDetailed && accounts.values.any((a) => a.id != id && a.isDetailed)) {
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
      if (change.entity != CategoryFields.entity) continue;
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

  /// Creates the tree of [year]: a copy of the tree of [sourceYearFor], of
  /// its mapping rules and of its redistribution rules, or, without one, the two empty groups « Revenus » and
  /// « Dépenses » (decisions H4 and H6). Copies get computed identifiers
  /// (design rule 4); a copied rule targets the copy of its category.
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
    for (final rule in rulesOf(source)) {
      for (final field in {
        RuleFields.year: year,
        RuleFields.keywords: encodeKeywords(rule.keywords),
        RuleFields.targetCategoryId: rule.targetCategoryId == null
            ? null
            : copiedCategoryId(rule.targetCategoryId!, year),
        RuleFields.targetAccountId: rule.targetAccountId,
        RuleFields.periodModel: rule.periodModel?.name,
        RuleFields.periodMonths: rule.periodMonths,
      }.entries) {
        changes.add(FieldChange(RuleFields.entity, copiedRuleId(rule.id, year), field.key, field.value));
      }
    }
    // Redistribution rules follow the copy too, with their categories
    // transposed (step 4.2).
    for (final rule in redistributionsOf(year)) {
      for (final field in {
        RedistributionFields.year: rule.year,
        RedistributionFields.sourceCategoryId: rule.sourceId,
        RedistributionFields.targetCategoryId: rule.targetId,
        RedistributionFields.basisPoints: rule.basisPoints,
      }.entries) {
        changes.add(FieldChange(RedistributionFields.entity, rule.id, field.key, field.value));
      }
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
  ///
  /// A detached category (decision H4 of phase 2) is moved the same way, to
  /// the top level or under a category of its year's tree: this is how it is
  /// put back, with the categories below it.
  Modification moveCategory(String id, {String? parentId, CategoryNature? nature}) {
    final category = categories[id] ?? forest.detached[id]?.category;
    if (category == null) throw const LedgerException(LedgerError.unknownCategory);
    final tree = trees[category.year];
    if (parentId == null) {
      if (nature == null) throw const LedgerException(LedgerError.natureRequired);
    } else {
      if (tree == null) throw const LedgerException(LedgerError.unknownCategory);
      if (tree.byId.containsKey(id) && tree.subtreeOf(id).contains(parentId)) {
        throw const LedgerException(LedgerError.categoryLoop);
      }
      _checkParent(tree, parentId);
    }
    final siblings = (parentId == null ? tree?.roots ?? const <Category>[] : tree!.childrenOf(parentId)).where(
      (c) => c.id != id,
    );
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
  /// transactions, mapping rules or redistribution rules (decision H2 of
  /// phase 4) use it, with their number.
  Modification removeCategory(String id) {
    final category = _category(id);
    if (trees[category.year]!.hasChildren(id)) throw const LedgerException(LedgerError.categoryHasChildren);
    final used = transactionsUsingCategory(id);
    if (used > 0) throw LedgerException(LedgerError.categoryInUse, count: used);
    final targeting = rules.values.where((r) => r.targetCategoryId == id).length;
    if (targeting > 0) throw LedgerException(LedgerError.categoryUsedByRules, count: targeting);
    final redistributing = redistributions.values.where((r) => r.sourceId == id || r.targetId == id).length;
    if (redistributing > 0) throw LedgerException(LedgerError.categoryUsedByRedistributions, count: redistributing);
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

  /// The transactions that answer [query], by payment date, most recent
  /// first (Transactions: search and filters, specification 4.6).
  List<LedgerTransaction> search(TransactionQuery query) {
    final words = normalizeText(query.text).split(' ').where((w) => w.isNotEmpty).toList();
    final category = query.categoryName == null ? null : normalizeName(query.categoryName!);
    return [
      for (final t in transactionList(accountId: query.accountId, year: query.year))
        if ((query.month == null || t.date.month == query.month) &&
            (query.status == null || _hasStatus(t, query.status!)) &&
            (category == null || _inCategory(t, category)) &&
            (words.isEmpty || _matchesWords(t, words)))
          t,
    ];
  }

  bool _hasStatus(LedgerTransaction t, StatusFilter status) => switch (status) {
    StatusFilter.toValidate => !t.isValidated,
    StatusFilter.toComplete => validationStateOf(t) == ValidationState.toComplete,
    StatusFilter.proposed => validationStateOf(t) == ValidationState.proposed,
    StatusFilter.validated => t.isValidated,
  };

  /// [normalized] is a normalised category name, or the empty string for
  /// the unclassified lines (no category, transfers excluded).
  bool _inCategory(LedgerTransaction t, String normalized) {
    final category = categoryOf(t);
    if (normalized.isEmpty) return category == null && kindOf(t) != TransactionKind.transfer;
    return category != null && normalizeName(category.name) == normalized;
  }

  bool _matchesWords(LedgerTransaction t, List<String> words) {
    final haystack = normalizeText(
      [
        t.description,
        t.note,
        t.rawText ?? '',
        categoryOf(t)?.name ?? '',
        accounts[t.accountId]?.name ?? '',
        accounts[t.counterpartAccountId]?.name ?? '',
        _amountText(t.amount),
      ].join(' '),
    );
    return words.every(haystack.contains);
  }

  /// An amount as typed in a search: 1234.50, without sign or separators.
  static String _amountText(int cents) {
    final abs = cents.abs();
    return '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }

  /// The names of the categories that hold transactions, in any year, for
  /// the category filter: categories of the same name are the same between
  /// years (specification, 4.1).
  List<String> get categoryNamesForFilter {
    final byNormalized = <String, String>{};
    for (final tree in trees.values) {
      for (final c in tree.assignable) {
        byNormalized.putIfAbsent(normalizeName(c.name), () => c.name);
      }
    }
    return byNormalized.values.toList()..sort((a, b) => normalizeName(a).compareTo(normalizeName(b)));
  }

  /// Years that have transactions, in increasing order.
  List<int> get yearsWithTransactions => {for (final t in transactions.values) t.date.year}.toList()..sort();

  /// The type of [transaction], deduced from its counterpart, the nature of
  /// its category and its sign; null while it is not classified.
  TransactionKind? kindOf(LedgerTransaction transaction) {
    if (!transaction.isValidated) {
      final classification = proposalOf(transaction);
      if (classification?.isTransfer ?? false) return TransactionKind.transfer;
    } else if (transaction.isTransfer) {
      return TransactionKind.transfer;
    }
    final category = categoryOf(transaction);
    if (category == null) return null;
    return switch (trees[category.year]!.natureOf(category.id)) {
      CategoryNature.income => TransactionKind.income,
      CategoryNature.expense => transaction.amount > 0 ? TransactionKind.refund : TransactionKind.expense,
    };
  }

  /// The category of the line of [transaction], if it is one of the tree of
  /// its payment year.
  ///
  /// For a line to validate, the category the rules propose (principle 3).
  /// For a refund attached to an expense, while the link holds, the category
  /// of the expense, in the tree of the expense's year (principle 5 of
  /// phase 4).
  Category? categoryOf(LedgerTransaction transaction) {
    if (transaction.isValidated && transaction.line != null) {
      if (refundedExpenseOf(transaction, transaction.line!) case final expense?) {
        return categories[expense.line.categoryId];
      }
    }
    final id = transaction.isValidated ? transaction.line?.categoryId : proposalOf(transaction)?.categoryId;
    final category = categories[id];
    return category != null && category.year == transaction.date.year ? category : null;
  }

  // ----------------------------------------------------------------- refunds

  /// Every line, by identifier, with its transaction.
  late final Map<String, LineOf> linesById = {
    for (final t in transactions.values)
      for (final line in t.lines) line.id: (line: line, transaction: t),
  };

  /// Whether [line] of [transaction] is a validated expense: money that
  /// left, in a category of expense of the tree of its payment year (decision
  /// H4 of phase 4: what a refund can be attached to).
  bool isExpenseLine(LedgerTransaction transaction, TransactionLine line) {
    if (!transaction.isValidated || transaction.isTransfer || line.amount >= 0) return false;
    final tree = trees[transaction.date.year];
    final categoryId = line.categoryId;
    return tree != null &&
        categoryId != null &&
        tree.byId.containsKey(categoryId) &&
        tree.natureOf(categoryId) == CategoryNature.expense;
  }

  /// The expense line that [line] of [transaction] refunds, while the link
  /// holds (principle 5 of phase 4): the refund is validated money that came
  /// in, not a transfer, and its link leads to a validated expense. Null
  /// otherwise: the line then counts with its own category and period. A
  /// link is followed one step only: a chain made by two devices leads to a
  /// refund, never an expense, and has no effect.
  LineOf? refundedExpenseOf(LedgerTransaction transaction, TransactionLine line) {
    final id = line.refundedLineId;
    if (id == null || !transaction.isValidated || transaction.isTransfer || line.amount <= 0) return null;
    final expense = linesById[id];
    if (expense == null || !isExpenseLine(expense.transaction, expense.line)) return null;
    return expense;
  }

  /// The refunds attached to each expense line whose link holds, by date.
  late final Map<String, List<LedgerTransaction>> refundsByExpenseLine = () {
    final result = <String, List<LedgerTransaction>>{};
    for (final t in transactions.values) {
      for (final line in t.lines) {
        if (refundedExpenseOf(t, line) case final expense?) (result[expense.line.id] ??= []).add(t);
      }
    }
    for (final list in result.values) {
      list.sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    }
    return result;
  }();

  /// The category a refund attached to an expense of category
  /// [expenseCategoryId] keeps as its own, in the tree of [year], its
  /// payment year (step 4.3): the category of the same name, else
  /// [current] when it can still hold it, else none.
  String? ownRefundCategory(int year, String? expenseCategoryId, String? current) {
    final tree = treeOrPreview(year);
    final expenseCategory = categories[expenseCategoryId];
    final named = expenseCategory == null ? null : tree.named(expenseCategory.name);
    if (named != null && tree.canHoldTransactions(named.id)) return named.id;
    return current != null && tree.canHoldTransactions(current) ? current : null;
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
      ..._entryChanges(id, existing.line?.id ?? fallbackLineId(id), draft, existing: existing.line),
      ...treeChangesFor(draft.date.year),
    ]);
  }

  /// The identifier of the line of a transaction that has lost its line.
  static String fallbackLineId(String transactionId) => '$transactionId-line';

  List<FieldChange> _entryChanges(String id, String lineId, EntryDraft draft, {TransactionLine? existing}) {
    if (draft.cents <= 0) throw const LedgerException(LedgerError.amountRequired);
    final tree = treeOrPreview(draft.date.year);
    final refunded = draft.refundedLineId;
    final String? categoryId;
    final CalendarDate start, end;
    if (refunded == null) {
      categoryId = draft.categoryId;
      if (categoryId == null || !tree.canHoldTransactions(categoryId)) {
        throw const LedgerException(LedgerError.categoryNotAssignable);
      }
      start = draft.periodStart ?? draft.date;
      end = draft.periodEnd ?? (draft.periodStart == null ? draft.date : start);
      if (end.isBefore(start)) throw const LedgerException(LedgerError.periodInvalid);
    } else {
      // A refund attached to an expense (decision H4 of phase 4): its own
      // category and its date serve only if the link breaks.
      if (draft.direction != Direction.inflow) throw const LedgerException(LedgerError.refundNotInflow);
      final expense = linesById[refunded];
      if (expense == null || expense.transaction.id == id || !isExpenseLine(expense.transaction, expense.line)) {
        throw const LedgerException(LedgerError.refundTargetNotExpense);
      }
      categoryId = ownRefundCategory(draft.date.year, expense.line.categoryId, draft.categoryId);
      start = end = draft.date;
    }
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
        LineFields.categoryId: categoryId,
        LineFields.amount: amount,
        LineFields.periodStart: start.encode(),
        LineFields.periodEnd: end.encode(),
        if (refunded != null || existing?.refundedLineId != null) LineFields.refundedLineId: refunded,
      }.entries)
        FieldChange(LineFields.entity, lineId, field.key, field.value),
    ];
  }

  /// Records a transfer: one transaction on the account the money leaves,
  /// with the receiving account as counterpart, and no category. Like any
  /// first transaction of a year without a tree, it creates that tree in the
  /// same modification (step 1.3 of the phase 1 plan, decision H6).
  Modification recordTransfer(String id, TransferDraft draft) {
    return Modification([
      ..._transferChanges(id, draft, previous: null),
      FieldChange(TransactionFields.entity, id, TransactionFields.status, TransactionStatus.validated.name),
      ...treeChangesFor(draft.date.year),
    ]);
  }

  Modification updateTransfer(String id, TransferDraft draft) {
    final existing = _manualTransaction(id);
    if (!existing.isTransfer) throw const LedgerException(LedgerError.unknownTransaction);
    return Modification([..._transferChanges(id, draft, previous: existing), ...treeChangesFor(draft.date.year)]);
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
    // Its amount, date, account and text come from the bank, even if import
    // was disabled on the account since.
    if (transaction.isImported) throw const LedgerException(LedgerError.importedTransaction);
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

  // -------------------------------------------------------------- statements

  /// The statements of [accountId], by period.
  List<Statement> statementsOf(String accountId) => [
    for (final s in statements.values)
      if (s.accountId == accountId) s,
  ]..sort(_byPeriod);

  static int _byPeriod(Statement a, Statement b) {
    final byEnd = a.periodEnd.compareTo(b.periodEnd);
    return byEnd != 0 ? byEnd : a.id.compareTo(b.id);
  }

  /// The latest statement of [accountId], the only one that can be deleted.
  Statement? lastStatementOf(String accountId) {
    final list = statementsOf(accountId);
    return list.isEmpty ? null : list.last;
  }

  /// The lines of the statement [id], in their order.
  List<LedgerTransaction> linesOf(String id) => [
    for (final t in transactions.values)
      if (t.statementId == id) t,
  ]..sort((a, b) => (a.statementRank ?? 0).compareTo(b.statementRank ?? 0));

  /// Imports [extracted], read by the server from the file of [fingerprint],
  /// into the detailed account [accountId]: the statement and all its lines,
  /// to validate, in one modification (principle 1 of phase 3), with the
  /// copy of the category tree of each year a line opens. Identifiers are
  /// computed from the account, the fingerprint and the rank of each line
  /// (principle 2): two devices importing the same file write the same
  /// records.
  ///
  /// Refused as a whole, nothing written, with a [StatementRefusedException]:
  /// the account is not detailed or reads another format; the statement was
  /// already imported (decision H1); its IBAN differs from the account's
  /// earlier statements; it does not follow the latest one (the day after it
  /// and its closing balance are expected); its lines do not add up to the
  /// difference of its balances; it is too large for one modification.
  StatementImport importStatement(String accountId, ExtractedStatement extracted, {required String fingerprint}) {
    final account = accounts[accountId];
    if (account == null) throw const LedgerException(LedgerError.unknownAccount);
    if (!account.isDetailed) throw const StatementRefusedException(LedgerError.accountNotDetailed);
    if (account.importFormat!.name != extracted.format) {
      throw const StatementRefusedException(LedgerError.statementOtherFormat);
    }
    final id = statementId(accountId, fingerprint);
    if (statements.containsKey(id)) throw const StatementRefusedException(LedgerError.statementAlreadyImported);
    final last = lastStatementOf(accountId);
    if (last != null && last.iban != extracted.iban) {
      throw StatementRefusedException(
        LedgerError.statementOtherAccount,
        expectedIban: last.iban,
        foundIban: extracted.iban,
      );
    }
    if (last != null) {
      final expectedStart = last.periodEnd.addDays(1);
      if (extracted.periodStart != expectedStart || extracted.openingBalance != last.closingBalance) {
        throw StatementRefusedException(
          LedgerError.statementNotContiguous,
          expectedStart: expectedStart,
          foundStart: extracted.periodStart,
          expectedOpening: last.closingBalance,
          foundOpening: extracted.openingBalance,
        );
      }
    }
    final sum = extracted.lines.fold(0, (total, line) => total + line.amount);
    if (sum != extracted.closingBalance - extracted.openingBalance) {
      throw const StatementRefusedException(LedgerError.statementSumMismatch);
    }

    // Imported again after a deletion (H8): its records come back, reset.
    final again = deletedStatementIds.contains(id);
    final changes = <FieldChange>[
      for (final field in {
        StatementFields.accountId: accountId,
        StatementFields.format: extracted.format,
        StatementFields.iban: extracted.iban,
        StatementFields.periodStart: extracted.periodStart.encode(),
        StatementFields.periodEnd: extracted.periodEnd.encode(),
        StatementFields.openingBalance: extracted.openingBalance,
        StatementFields.closingBalance: extracted.closingBalance,
        StatementFields.fingerprint: fingerprint,
        if (again) deletedField: false,
      }.entries)
        FieldChange(StatementFields.entity, id, field.key, field.value),
    ];
    for (final (rank, line) in extracted.lines.indexed) {
      final transactionId = importedTransactionId(id, rank);
      for (final field in {
        TransactionFields.accountId: accountId,
        TransactionFields.date: line.date.encode(),
        TransactionFields.amount: line.amount,
        TransactionFields.rawText: line.rawText,
        TransactionFields.description: line.label,
        TransactionFields.status: TransactionStatus.toValidate.name,
        TransactionFields.statementId: id,
        TransactionFields.statementRank: rank,
        if (again) ...{deletedField: false, TransactionFields.counterpartAccountId: null, TransactionFields.note: ''},
      }.entries) {
        changes.add(FieldChange(TransactionFields.entity, transactionId, field.key, field.value));
      }
    }
    for (final year in {for (final line in extracted.lines) line.date.year}.toList()..sort()) {
      changes.addAll(treeChangesFor(year));
    }
    if (changes.length > maxModificationChanges) throw const StatementRefusedException(LedgerError.statementTooLarge);
    return StatementImport(modification: Modification(changes), statementId: id, first: last == null);
  }

  /// Deletes the statement [id] and all its lines (decision H8): only the
  /// latest statement of its account, so that the others stay contiguous. It
  /// can then be imported again.
  Modification deleteLastStatement(String id) {
    final statement = statements[id];
    if (statement == null) throw const LedgerException(LedgerError.unknownStatement);
    if (lastStatementOf(statement.accountId)?.id != id) throw const LedgerException(LedgerError.statementNotLast);
    return Modification([
      FieldChange(StatementFields.entity, id, deletedField, true),
      for (final t in linesOf(id)) ...[
        FieldChange(TransactionFields.entity, t.id, deletedField, true),
        for (final line in t.lines) FieldChange(LineFields.entity, line.id, deletedField, true),
      ],
    ]);
  }

  /// Changes the description and the note of the imported line [id]: its
  /// amount, date, account and text stay those of the bank (4.3).
  Modification updateImportedDetails(String id, {required String description, required String note}) {
    final transaction = transactions[id];
    if (transaction == null || !transaction.isImported) throw const LedgerException(LedgerError.unknownTransaction);
    return Modification.set(TransactionFields.entity, id, {
      TransactionFields.description: description.trim(),
      TransactionFields.note: note.trim(),
    });
  }

  // ------------------------------------------------------------------- rules

  /// The mapping rules of [year], by first keyword.
  List<MappingRule> rulesOf(int year) =>
      [
        for (final r in rules.values)
          if (r.year == year) r,
      ]..sort((a, b) {
        final byKeyword = normalizeText(a.keywords.join(' ')).compareTo(normalizeText(b.keywords.join(' ')));
        return byKeyword != 0 ? byKeyword : a.id.compareTo(b.id);
      });

  /// What [rule] classifies a payment of [payment] as, or null when its
  /// target can no longer be used: a category that is deleted, detached, a
  /// group or not of its year's tree; an account that is gone, archived or
  /// detailed.
  Classification? ruleClassification(MappingRule rule, CalendarDate payment) {
    if (rule.targetAccountId case final accountId?) {
      final account = accounts[accountId];
      if (account == null || account.archived || account.isDetailed) return null;
      return Classification.transfer(accountId);
    }
    final categoryId = rule.targetCategoryId;
    final tree = trees[rule.year];
    if (categoryId == null || tree == null || !tree.canHoldTransactions(categoryId)) return null;
    if ((rule.periodModel?.takesMonths ?? false) &&
        (rule.periodMonths == null || rule.periodMonths! < 1 || rule.periodMonths! > maxPeriodMonths)) {
      return null;
    }
    final (start, end) = periodFor(rule.periodModel, payment, months: rule.periodMonths);
    return Classification.category(categoryId, periodStart: start, periodEnd: end);
  }

  /// Rules whose target can no longer be used: they propose nothing and are
  /// listed in the tasks.
  late final List<MappingRule> unusableRules = [
    for (final year in {for (final r in rules.values) r.year}.toList()..sort())
      for (final rule in rulesOf(year))
        if (ruleClassification(rule, CalendarDate(rule.year, 6, 15)) == null) rule,
  ];

  /// What the rules say of each line to validate, recomputed at each load
  /// from its raw text and the rules of its payment year (principle 3).
  late final Map<String, RuleOutcome> proposals = () {
    final byYear = <int, List<MappingRule>>{};
    for (final rule in rules.values) {
      (byYear[rule.year] ??= []).add(rule);
    }
    return {
      for (final t in transactions.values)
        if (!t.isValidated)
          t.id: outcomeOf(t.rawText ?? '', byYear[t.date.year] ?? const [], (r) => ruleClassification(r, t.date)),
    };
  }();

  /// The classification the rules propose for [transaction], if any.
  Classification? proposalOf(LedgerTransaction transaction) => switch (proposals[transaction.id]) {
    Proposed(:final classification) => classification,
    _ => null,
  };

  /// Where [transaction] stands in the validation.
  ValidationState validationStateOf(LedgerTransaction transaction) {
    if (transaction.isValidated) return ValidationState.validated;
    return proposals[transaction.id] is Proposed ? ValidationState.proposed : ValidationState.toComplete;
  }

  /// The lines to validate, by date then rank.
  List<LedgerTransaction> get linesToValidate => [
    for (final t in transactions.values)
      if (!t.isValidated) t,
  ]..sort(_byDateAndRank);

  static int _byDateAndRank(LedgerTransaction a, LedgerTransaction b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byStatement = (a.statementId ?? '').compareTo(b.statementId ?? '');
    if (byStatement != 0) return byStatement;
    return (a.statementRank ?? 0).compareTo(b.statementRank ?? 0);
  }

  /// Creates the rule [id] of [RuleDraft.year]. Refused without a tree for
  /// the year, without a keyword, with an invalid regular expression, without
  /// a usable target, or with a number of months out of range.
  Modification createRule(String id, RuleDraft draft) => Modification.set(RuleFields.entity, id, _ruleFields(draft));

  /// Modifies the rule [id]: only the rule is written, the lines to validate
  /// follow at the next load and validated lines never change.
  Modification updateRule(String id, RuleDraft draft) {
    final rule = rules[id];
    if (rule == null) throw const LedgerException(LedgerError.unknownRule);
    if (draft.year != rule.year) throw const LedgerException(LedgerError.unknownRule);
    return Modification.set(RuleFields.entity, id, _ruleFields(draft, existing: rule));
  }

  Modification deleteRule(String id) {
    if (!rules.containsKey(id)) throw const LedgerException(LedgerError.unknownRule);
    return Modification.delete(RuleFields.entity, id);
  }

  Map<String, Object?> _ruleFields(RuleDraft draft, {MappingRule? existing}) {
    final tree = trees[draft.year];
    if (tree == null) throw const LedgerException(LedgerError.noTree);
    final keywords = [
      for (final k in draft.keywords)
        if (k.trim().isNotEmpty) k.trim(),
    ];
    if (keywords.isEmpty) throw const LedgerException(LedgerError.ruleKeywordsRequired);
    for (final keyword in keywords) {
      if (!isValidKeyword(keyword)) throw const LedgerException(LedgerError.ruleKeywordInvalid);
    }
    final category = draft.targetCategoryId, accountId = draft.targetAccountId;
    if ((category == null) == (accountId == null)) throw const LedgerException(LedgerError.ruleTargetRequired);
    if (category != null && !tree.canHoldTransactions(category)) {
      throw const LedgerException(LedgerError.categoryNotAssignable);
    }
    if (accountId != null) {
      final account = accounts[accountId];
      final unchanged = accountId == existing?.targetAccountId;
      if (account == null) throw const LedgerException(LedgerError.unknownAccount);
      if (account.archived && !unchanged) throw const LedgerException(LedgerError.archivedAccount);
      if (account.isDetailed) throw const LedgerException(LedgerError.detailedAccountManual);
    }
    final model = accountId == null ? draft.periodModel : null;
    final months = model?.takesMonths ?? false ? draft.periodMonths : null;
    if ((model?.takesMonths ?? false) && (months == null || months < 1 || months > maxPeriodMonths)) {
      throw const LedgerException(LedgerError.rulePeriodInvalid);
    }
    return {
      RuleFields.year: draft.year,
      RuleFields.keywords: encodeKeywords(keywords),
      RuleFields.targetCategoryId: category,
      RuleFields.targetAccountId: accountId,
      RuleFields.periodModel: model?.name,
      RuleFields.periodMonths: months,
    };
  }

  /// How many lines to validate of [RuleDraft.year] the rule would classify
  /// once created (or once [replacing] is modified so): those it would
  /// propose, alone or with rules of the same result.
  int linesClassifiedBy(RuleDraft draft, {String? replacing}) {
    final List<String> keywords = [
      for (final k in draft.keywords)
        if (k.trim().isNotEmpty && isValidKeyword(k)) k.trim(),
    ];
    if (keywords.isEmpty) return 0;
    final candidate = MappingRule(
      id: replacing ?? '~draft',
      year: draft.year,
      keywords: keywords,
      targetCategoryId: draft.targetCategoryId,
      targetAccountId: draft.targetAccountId,
      periodModel: draft.targetAccountId == null ? draft.periodModel : null,
      periodMonths: draft.targetAccountId == null ? draft.periodMonths : null,
    );
    final others = [
      for (final r in rulesOf(draft.year))
        if (r.id != replacing) r,
      candidate,
    ];
    var count = 0;
    for (final t in transactions.values) {
      if (t.isValidated || t.date.year != draft.year) continue;
      final text = normalizeText(t.rawText ?? '');
      if (!candidate.matches(text)) continue;
      final outcome = outcomeOf(t.rawText ?? '', others, (r) => ruleClassification(r, t.date));
      if (outcome is Proposed && outcome.rule.result == candidate.result) count++;
    }
    return count;
  }

  // -------------------------------------------------------------- validation

  /// Classifies the imported line [id] (principle 4): writes its category and
  /// period, or its counterpart account, and validates it. Correcting a
  /// proposal is classifying it (decision H4); a validated line stays
  /// modifiable the same way.
  Modification classify(String id, Classification classification) {
    final transaction = transactions[id];
    if (transaction == null || !transaction.isImported) throw const LedgerException(LedgerError.unknownTransaction);
    return Modification(_classificationChanges(transaction, classification));
  }

  /// Classifies the imported line [id] and sets its description and note,
  /// in one modification: what the validation screen writes.
  Modification validateLine(
    String id,
    Classification classification, {
    required String description,
    required String note,
  }) {
    final transaction = transactions[id];
    if (transaction == null || !transaction.isImported) throw const LedgerException(LedgerError.unknownTransaction);
    return Modification([
      ..._classificationChanges(transaction, classification),
      FieldChange(TransactionFields.entity, id, TransactionFields.description, description.trim()),
      FieldChange(TransactionFields.entity, id, TransactionFields.note, note.trim()),
    ]);
  }

  /// The lines to validate whose rules compete (decision H5).
  int get conflictingLines => proposals.values.whereType<Conflict>().length;

  /// Confirms the proposals of the lines [ids] that have one (the others are
  /// left out): one modification, unless the lines are too many for one, in
  /// which case each modification holds whole lines.
  List<Modification> confirmProposals(Iterable<String> ids) {
    final groups = <List<FieldChange>>[];
    for (final id in ids) {
      final transaction = transactions[id];
      final outcome = proposals[id];
      if (transaction == null || transaction.isValidated || outcome is! Proposed) continue;
      groups.add(_classificationChanges(transaction, outcome.classification));
    }
    final modifications = <Modification>[];
    var current = <FieldChange>[];
    for (final group in groups) {
      if (current.length + group.length > maxModificationChanges) {
        modifications.add(Modification(current));
        current = [];
      }
      current.addAll(group);
    }
    if (current.isNotEmpty) modifications.add(Modification(current));
    return modifications;
  }

  List<FieldChange> _classificationChanges(LedgerTransaction t, Classification c) {
    final changes = [
      FieldChange(TransactionFields.entity, t.id, TransactionFields.status, TransactionStatus.validated.name),
    ];
    if (c.counterpartAccountId case final accountId?) {
      final account = accounts[accountId];
      if (account == null) throw const LedgerException(LedgerError.unknownAccount);
      if (accountId == t.accountId) throw const LedgerException(LedgerError.sameAccount);
      if (account.archived && accountId != t.counterpartAccountId) {
        throw const LedgerException(LedgerError.archivedAccount);
      }
      if (account.isDetailed) throw const LedgerException(LedgerError.detailedAccountManual);
      // The amount keeps the statement's sign: negative, the money goes to
      // the counterpart; positive, it comes from it. A transfer has no line.
      changes.add(FieldChange(TransactionFields.entity, t.id, TransactionFields.counterpartAccountId, accountId));
      for (final line in t.lines) {
        changes.add(FieldChange(LineFields.entity, line.id, deletedField, true));
      }
      return changes;
    }
    final categoryId = c.categoryId!;
    final tree = trees[t.date.year];
    if (tree == null || !tree.canHoldTransactions(categoryId)) {
      throw const LedgerException(LedgerError.categoryNotAssignable);
    }
    final start = c.periodStart ?? t.date, end = c.periodEnd ?? t.date;
    if (end.isBefore(start)) throw const LedgerException(LedgerError.periodInvalid);
    if (t.counterpartAccountId != null) {
      changes.add(FieldChange(TransactionFields.entity, t.id, TransactionFields.counterpartAccountId, null));
    }
    final lineId = t.line?.id ?? fallbackLineId(t.id);
    for (final field in {
      LineFields.transactionId: t.id,
      LineFields.categoryId: categoryId,
      LineFields.amount: t.amount,
      LineFields.periodStart: start.encode(),
      LineFields.periodEnd: end.encode(),
      // A line deleted with its statement, or by a transfer, comes back; a
      // category chosen detaches a refund (step 4.3), and a line brought
      // back must not bring back an old link.
      if (t.line == null) deletedField: false,
      if (t.line == null || t.line!.refundedLineId != null) LineFields.refundedLineId: null,
    }.entries) {
      changes.add(FieldChange(LineFields.entity, lineId, field.key, field.value));
    }
    return changes;
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

/// Where a line stands in the validation; only « validated » is stored, the
/// other two are deduced from the rules (principle 3 of phase 3).
enum ValidationState { toComplete, proposed, validated }

/// Whether [keyword] can be a keyword of a rule: a regular expression
/// (`re:…`) must be valid.
bool isValidKeyword(String keyword) {
  try {
    Keyword(keyword);
    return true;
  } on FormatException {
    return false;
  }
}

/// The statuses the transactions list filters on.
enum StatusFilter { toValidate, toComplete, proposed, validated }

/// What the transactions list asks for: words to find (in the description,
/// the note, the bank's text, the category, the accounts or the amount, each
/// word required, without case or accents) and filters. A null filter keeps
/// everything; an empty [categoryName] keeps the unclassified lines.
class TransactionQuery {
  const TransactionQuery({this.text = '', this.accountId, this.year, this.month, this.categoryName, this.status});

  final String text;
  final String? accountId;
  final int? year;
  final int? month;
  final String? categoryName;
  final StatusFilter? status;
}

/// A line and its transaction.
typedef LineOf = ({TransactionLine line, LedgerTransaction transaction});
