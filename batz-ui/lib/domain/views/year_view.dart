/// The annual view (specification, 4.6 « Année »; plan of phase 4): for one
/// year, the category tree with its amounts month by month, in the
/// cash-flow view (what was paid in the year) or in the economic view (what
/// the year cost).
///
/// Computed at each load from what the user entered, never stored
/// (principle 1), and one calculation serves both views (principle 2): each
/// line of a transaction gives amounts dated by month, a single one at the
/// month of its payment in the cash-flow view, one per monthly share of its
/// period in the economic view. Everything else is common: the category
/// chosen in the tree of the month's year, the sums of the groups, the
/// totals. The two views can thus differ only by where the amounts fall.
/// The rules are described in docs/year-view.md.
library;

import 'package:equatable/equatable.dart';

import '../allocation.dart';
import '../calendar_date.dart';
import '../ledger/category.dart';
import '../ledger/ledger.dart';
import '../ledger/redistribution.dart';
import '../ledger/transaction.dart';

/// The two views of a year (specification, 4.2).
enum ViewKind {
  /// Every amount at its payment date.
  cash,

  /// Every amount spread over the months of the period it concerns.
  economic,
}

/// Twelve signed amounts in cents, January first.
class MonthlyAmounts extends Equatable {
  MonthlyAmounts(Iterable<int> months) : months = List.unmodifiable(months) {
    if (this.months.length != 12) throw ArgumentError.value(this.months.length, 'months', 'twelve expected');
  }

  static final zero = MonthlyAmounts(List.filled(12, 0));

  final List<int> months;

  /// The amount of [month], from 1 to 12.
  int month(int month) => months[month - 1];

  /// The total of the year: the sum of the twelve months.
  int get total => months.fold(0, (sum, m) => sum + m);

  bool get isZero => months.every((m) => m == 0);

  MonthlyAmounts operator +(MonthlyAmounts other) =>
      MonthlyAmounts([for (var i = 0; i < 12; i++) months[i] + other.months[i]]);

  MonthlyAmounts operator -() => MonthlyAmounts([for (final m in months) -m]);

  @override
  List<Object?> get props => [months];

  @override
  String toString() => '$months';
}

/// A line of the view whose amount is made of transactions: a category (with
/// everything below it for a group), « À classer » of a nature, or
/// « Non classé ».
sealed class ViewRow extends Equatable {
  const ViewRow();
}

class CategoryRow extends ViewRow {
  const CategoryRow(this.categoryId);

  final String categoryId;

  @override
  List<Object?> get props => [categoryId];
}

/// The amounts whose category has no counterpart in the year (principle 3).
class ToClassifyRow extends ViewRow {
  const ToClassifyRow(this.nature);

  final CategoryNature nature;

  @override
  List<Object?> get props => [nature];
}

/// The lines without a usable category, at their payment date in both views.
class UnclassifiedRow extends ViewRow {
  const UnclassifiedRow();

  @override
  List<Object?> get props => [];
}

/// What a redistribution rule moves in a view (principle 4): month by
/// month, its percentage of what the source shows before any
/// redistribution, rounded to the cent, leaves the source and joins the
/// target, on a line of its own on each side.
class RedistributionLine {
  const RedistributionLine(this.rule, this.moved);

  final RedistributionRule rule;

  /// The amounts moved, signed as they add to the target: negative for
  /// expenses. Under the source the line shows their opposite.
  final MonthlyAmounts moved;
}

/// A transaction and the part of it a row counts.
class Contribution extends Equatable {
  const Contribution(this.transaction, this.cents);

  final LedgerTransaction transaction;
  final int cents;

  @override
  List<Object?> get props => [transaction.id, cents];
}

/// One view of one year.
class YearView {
  YearView._({
    required this.year,
    required this.kind,
    required this.tree,
    required this.isPreview,
    required Map<String, MonthlyAmounts> categories,
    required Map<CategoryNature, MonthlyAmounts> toClassify,
    required this.unclassified,
    required this.income,
    required this.expenses,
    required this.paidForOtherYears,
    required this.paidInOtherYears,
    required this.linesToValidate,
    required List<RedistributionLine> redistributions,
    required List<InapplicableRedistribution> inapplicable,
  }) : categories = Map.unmodifiable(categories),
       toClassify = Map.unmodifiable(toClassify),
       redistributions = List.unmodifiable(redistributions),
       inapplicable = List.unmodifiable(inapplicable);

  final int year;
  final ViewKind kind;

  /// The tree of the year, or for a year to come that has none yet, the
  /// tree its copy will give (decision H6).
  final CategoryTree tree;

  /// Whether [tree] is the copy to come rather than a tree written.
  final bool isPreview;

  /// The amounts of each category of [tree]: for a category without
  /// children, what is classified in it, before redistribution; for a
  /// group, the sum of its children and of their redistribution lines, plus
  /// what was classified in it directly before it became a group (only a
  /// merge of two devices can do that).
  final Map<String, MonthlyAmounts> categories;

  /// The redistribution rules that apply in the year, with what they move,
  /// by source then target name; their lines show under the source and
  /// under the target (decision H1: in both views).
  final List<RedistributionLine> redistributions;

  /// The rules of the year that do not apply, and why (principle 6).
  final List<InapplicableRedistribution> inapplicable;

  /// What the redistribution lines of [categoryId] add to it: what joins it
  /// as a target minus what leaves it as a source.
  MonthlyAmounts redistributedOf(String categoryId) => redistributions.fold(MonthlyAmounts.zero, (sum, line) {
    if (line.rule.targetId == categoryId) return sum + line.moved;
    if (line.rule.sourceId == categoryId) return sum + -line.moved;
    return sum;
  });

  /// « À classer », by nature: amounts that fell in this year from a
  /// category of another year without a counterpart here. They count in the
  /// income or the expenses.
  final Map<CategoryNature, MonthlyAmounts> toClassify;

  /// « Non classé »: lines without a usable category, at their payment date
  /// in both views, outside income and expenses.
  final MonthlyAmounts unclassified;

  /// Income: the income groups and « À classer » of their nature.
  final MonthlyAmounts income;

  /// Expenses, signed as paid: negative, refunds included.
  final MonthlyAmounts expenses;

  /// Income minus expenses (specification, 4.1).
  MonthlyAmounts get savings => income + expenses;

  /// Period offsets of the year, signed as a result (income positive,
  /// expenses negative), the same in both views: what was paid in this year
  /// for other years, and what was paid in other years for this one. The
  /// cash-flow result is the economic result plus the first minus the
  /// second.
  final int paidForOtherYears;
  final int paidInOtherYears;

  /// How many lines to validate give amounts to this view: they count as
  /// their rules propose, or as unclassified.
  final int linesToValidate;

  /// The total of the year of [categoryId], 0 if it is not in [tree].
  int totalOf(String categoryId) => categories[categoryId]?.total ?? 0;

  /// The total of the year of every category of [tree].
  Map<String, int> get totals => {for (final e in categories.entries) e.key: e.value.total};
}

/// Where an amount goes in the view of a year.
sealed class _Target {
  const _Target();
}

class _InCategory extends _Target {
  const _InCategory(this.id);

  final String id;
}

class _ToClassify extends _Target {
  const _ToClassify(this.nature);

  final CategoryNature nature;
}

class _Unclassified extends _Target {
  const _Unclassified();
}

/// An amount of a line, before it is placed in a year (principle 2).
class _Flow {
  _Flow({
    required this.transaction,
    required this.origin,
    required this.originYear,
    required this.nature,
    required this.amount,
    required this.start,
    required this.end,
  });

  final LedgerTransaction transaction;

  /// The category of the line in the tree of its payment year; null when
  /// there is none (« Non classé »). For a refund attached to an expense,
  /// the category of the expense.
  final Category? origin;

  /// The year whose tree holds [origin]: the payment year of the line, or
  /// of the expense a refund is attached to.
  final int originYear;
  final CategoryNature? nature;
  final int amount;

  /// The period the amount concerns: for an attached refund, the period of
  /// the expense.
  final CalendarDate start;
  final CalendarDate end;

  /// The payment date: the cash-flow view places the amount there, an
  /// attached refund included (decision H3).
  CalendarDate get paid => transaction.date;

  /// The shares of the economic view: (year, month, cents).
  late final List<(int, int, int)> shares = start.year == end.year && start.month == end.month
      ? [(start.year, start.month, amount)]
      : [for (final share in allocate(amount, start, end)) (share.month.year, share.month.month, share.cents)];

  bool concerns(int year) => start.year <= year && end.year >= year;
}

/// The views of every year of a [Ledger], computed when first asked for.
class YearViews {
  YearViews(this.ledger);

  final Ledger ledger;

  /// The first year that has a tree; earlier years are not shown (H6).
  late final int? firstYear = ledger.trees.isEmpty ? null : ledger.trees.keys.reduce((a, b) => a < b ? a : b);

  /// The tree a year is shown with: its own, or the copy it will receive
  /// when an earlier year has a tree (H6). Null before the first tree.
  CategoryTree? treeOf(int year) {
    final first = firstYear;
    if (first == null || year < first) return null;
    return _trees.putIfAbsent(year, () => ledger.treeOrPreview(year));
  }

  final _trees = <int, CategoryTree>{};

  /// Whether [year] would be shown with the copy of an earlier tree.
  bool isPreview(int year) => treeOf(year) != null && !ledger.trees.containsKey(year);

  /// The years to offer: from the first tree to the latest year that has a
  /// tree, an amount, or is [currentYear].
  List<int> years({required int currentYear}) {
    final first = firstYear;
    if (first == null) return const [];
    var last = currentYear;
    for (final year in ledger.trees.keys) {
      if (year > last) last = year;
    }
    for (final flow in _flows) {
      final year = flow.origin == null
          ? flow.paid.year
          : (flow.end.year > flow.paid.year ? flow.end.year : flow.paid.year);
      if (year > last) last = year;
    }
    return [for (var year = first; year <= last; year++) year];
  }

  /// The view [kind] of [year]; null when [year] is not shown (H6).
  YearView? of(int year, ViewKind kind) => _views.putIfAbsent((year, kind), () => _build(year, kind));

  final _views = <(int, ViewKind), YearView?>{};

  /// The transactions that make the amount of [row] in the view [kind] of
  /// [year] (of [month] only, from 1 to 12, when given), with the part each
  /// one counts, by payment date.
  List<Contribution> composition(int year, ViewKind kind, ViewRow row, {int? month}) {
    final tree = treeOf(year);
    if (tree == null) return const [];
    final inRow = row is CategoryRow
        ? (tree.byId.containsKey(row.categoryId) ? tree.subtreeOf(row.categoryId) : <String>{})
        : null;
    final parts = <String, int>{};
    _place(year, kind, tree, (flow, target, m, cents) {
      if (month != null && m != month) return;
      final matches = switch (row) {
        CategoryRow() => target is _InCategory && inRow!.contains(target.id),
        ToClassifyRow(:final nature) => target is _ToClassify && target.nature == nature,
        UnclassifiedRow() => target is _Unclassified,
      };
      if (matches) parts[flow.transaction.id] = (parts[flow.transaction.id] ?? 0) + cents;
    });
    final transactions = ledger.transactions;
    return [for (final e in parts.entries) Contribution(transactions[e.key]!, e.value)]..sort((a, b) {
      final byDate = a.transaction.date.compareTo(b.transaction.date);
      return byDate != 0 ? byDate : a.transaction.id.compareTo(b.transaction.id);
    });
  }

  // ----------------------------------------------------------------- flows

  late final List<_Flow> _flows = _buildFlows();

  List<_Flow> _buildFlows() {
    final flows = <_Flow>[];
    void add(
      LedgerTransaction t,
      String? categoryId,
      int amount,
      CalendarDate start,
      CalendarDate end, {
      LedgerTransaction? of,
    }) {
      final year = (of ?? t).date.year;
      final tree = ledger.trees[year];
      final origin = categoryId == null ? null : tree?.byId[categoryId];
      flows.add(
        _Flow(
          transaction: t,
          origin: origin,
          originYear: year,
          nature: origin == null ? null : tree!.natureOf(origin.id),
          amount: amount,
          start: start,
          end: end,
        ),
      );
    }

    for (final t in ledger.transactions.values) {
      if (!t.isValidated) {
        // A line to validate counts as its rules propose: category and
        // period (principle 3 of phase 3); without a proposal, unclassified.
        final proposal = ledger.proposalOf(t);
        if (proposal?.isTransfer ?? false) continue;
        add(t, proposal?.categoryId, t.amount, proposal?.periodStart ?? t.date, proposal?.periodEnd ?? t.date);
        continue;
      }
      if (t.isTransfer) continue;
      if (t.lines.isEmpty) {
        add(t, null, t.amount, t.date, t.date);
        continue;
      }
      for (final line in t.lines) {
        // A refund attached to a validated expense follows it: category and
        // period (principle 5).
        if (ledger.refundedExpenseOf(t, line) case final expense?) {
          final paid = expense.line;
          add(t, paid.categoryId, line.amount, paid.periodStart, paid.periodEnd, of: expense.transaction);
          continue;
        }
        add(t, line.categoryId, line.amount, line.periodStart, line.periodEnd);
      }
    }
    return flows;
  }

  // ------------------------------------------------------------- placement

  /// The category of [year] that an amount of [flow] goes to (principle 3):
  /// its own category in the year of its payment; elsewhere the category of
  /// the same name, if it can hold transactions; otherwise « À classer ».
  _Target _target(_Flow flow, int year, CategoryTree tree) {
    final origin = flow.origin!;
    if (year == flow.originYear) return _InCategory(origin.id);
    final match = _sameName.putIfAbsent((origin.id, year), () {
      final named = tree.named(origin.name);
      return named != null && tree.canHoldTransactions(named.id) ? named.id : null;
    });
    if (match != null) return _InCategory(match);
    return _ToClassify(flow.nature!);
  }

  final _sameName = <(String, int), String?>{};

  /// Gives every amount that falls in [year] in the view [kind] to [sink],
  /// with its target and its month.
  void _place(
    int year,
    ViewKind kind,
    CategoryTree tree,
    void Function(_Flow flow, _Target target, int month, int cents) sink,
  ) {
    for (final flow in _flows) {
      if (flow.origin == null) {
        // Unclassified: at the payment date in both views.
        if (flow.paid.year == year) sink(flow, const _Unclassified(), flow.paid.month, flow.amount);
        continue;
      }
      switch (kind) {
        case ViewKind.cash:
          if (flow.paid.year == year) sink(flow, _target(flow, year, tree), flow.paid.month, flow.amount);
        case ViewKind.economic:
          if (!flow.concerns(year)) continue;
          _Target? target;
          for (final (y, m, cents) in flow.shares) {
            if (y == year) sink(flow, target ??= _target(flow, year, tree), m, cents);
          }
      }
    }
  }

  YearView? _build(int year, ViewKind kind) {
    final tree = treeOf(year);
    if (tree == null) return null;
    final own = {for (final id in tree.byId.keys) id: List.filled(12, 0)};
    final toClassify = {for (final nature in CategoryNature.values) nature: List.filled(12, 0)};
    final unclassified = List.filled(12, 0);
    final toValidate = <String>{};
    _place(year, kind, tree, (flow, target, month, cents) {
      switch (target) {
        case _InCategory(:final id):
          own[id]![month - 1] += cents;
        case _ToClassify(:final nature):
          toClassify[nature]![month - 1] += cents;
        case _Unclassified():
          unclassified[month - 1] += cents;
      }
      if (!flow.transaction.isValidated) toValidate.add(flow.transaction.id);
    });

    // Redistribution (principle 4): from what each source shows before any
    // redistribution, month by month.
    final rules = ledger.redistributionsOf(year);
    final problems = redistributionProblems(rules, tree);
    final lines = <RedistributionLine>[];
    final adjust = <String, List<int>>{};
    for (final rule in rules) {
      if (problems[rule.id] != null) continue;
      final moved = [for (final cents in own[rule.sourceId]!) redistributedCents(cents, rule.basisPoints)];
      lines.add(RedistributionLine(rule, MonthlyAmounts(moved)));
      final source = adjust.putIfAbsent(rule.sourceId, () => List.filled(12, 0));
      final target = adjust.putIfAbsent(rule.targetId, () => List.filled(12, 0));
      for (var i = 0; i < 12; i++) {
        source[i] -= moved[i];
        target[i] += moved[i];
      }
    }

    // A group adds up everything below it, redistribution lines included.
    final full = <String, List<int>>{};
    List<int> sum(String id) => full.putIfAbsent(id, () {
      final total = [...own[id]!];
      if (adjust[id] case final lines?) {
        for (var i = 0; i < 12; i++) {
          total[i] += lines[i];
        }
      }
      for (final child in tree.childrenOf(id)) {
        final amounts = sum(child.id);
        for (var i = 0; i < 12; i++) {
          total[i] += amounts[i];
        }
      }
      return total;
    });
    final categories = {for (final id in tree.byId.keys) id: MonthlyAmounts(tree.hasChildren(id) ? sum(id) : own[id]!)};
    MonthlyAmounts natureTotal(CategoryNature nature) => [
      for (final root in tree.roots)
        if (root.nature == nature) MonthlyAmounts(sum(root.id)),
    ].fold(MonthlyAmounts(toClassify[nature]!), (a, b) => a + b);

    // Period offsets: what was paid in this year for others, and in others
    // for this one.
    var paidFor = 0, paidIn = 0;
    for (final flow in _flows) {
      if (flow.origin == null) continue;
      final paidHere = flow.paid.year == year;
      if (!paidHere && !flow.concerns(year)) continue;
      for (final (y, _, cents) in flow.shares) {
        if (paidHere && y != year) paidFor += cents;
        if (!paidHere && y == year) paidIn += cents;
      }
    }

    return YearView._(
      year: year,
      kind: kind,
      tree: tree,
      isPreview: !ledger.trees.containsKey(year),
      categories: categories,
      toClassify: {for (final e in toClassify.entries) e.key: MonthlyAmounts(e.value)},
      unclassified: MonthlyAmounts(unclassified),
      income: natureTotal(CategoryNature.income),
      expenses: natureTotal(CategoryNature.expense),
      paidForOtherYears: paidFor,
      paidInOtherYears: paidIn,
      linesToValidate: toValidate.length,
      redistributions: lines,
      inapplicable: [
        for (final rule in rules)
          if (problems[rule.id] case final problem?) InapplicableRedistribution(rule, problem),
      ],
    );
  }
}

final _views = Expando<YearViews>('year views');

extension LedgerYearViews on Ledger {
  /// The annual views of this ledger, computed when first asked for and
  /// kept as long as the ledger: a new ledger is loaded after each write.
  YearViews get views => _views[this] ??= YearViews(this);
}
