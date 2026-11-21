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
import '../ledger/share_classification.dart';
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

  /// « Non classé »: lines without a usable category, and what a merge left
  /// between a transaction's amount and its lines, at their payment date in
  /// both views, outside income and expenses.
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

/// A line and what it places in a category of a year, month by month
/// ([YearViews.linesIn]).
class CategoryLine {
  const CategoryLine(this.line, this.months);

  final ViewLine line;
  final MonthlyAmounts months;

  int get total => months.total;
}

/// A line whose shares in a year have no category there (decision H5).
class PendingShare {
  const PendingShare({required this.lineId, required this.transaction, required this.economic, required this.cash});

  final String lineId;

  /// The transaction of the line: for the shares of attached refunds, the
  /// expense they follow.
  final LedgerTransaction transaction;

  /// What « À classer » holds of the line in the year, in the economic view
  /// and in the cash-flow view (only refunds paid in another year than
  /// their expense give an amount there).
  final int economic;
  final int cash;
}

/// The lines of one category of origin whose shares in one year are to
/// classify: one answer serves them all, each can be answered alone.
class PendingShareGroup {
  const PendingShareGroup({
    required this.origin,
    required this.originYear,
    required this.nature,
    required this.year,
    required this.shares,
  });

  final Category origin;
  final int originYear;
  final CategoryNature nature;

  /// The year the shares fall in.
  final int year;
  final List<PendingShare> shares;
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

/// An amount of a line, before it is placed in a year (principle 2 of
/// phase 4): what the views count, read by the modules (step 6.0 of phase
/// 6) without classifying or spreading anything again.
class ViewLine {
  ViewLine._({
    required this.transaction,
    required this.ownLineId,
    required this.lineId,
    required this.origin,
    required this.originYear,
    required this.nature,
    required this.amount,
    required this.start,
    required this.end,
  });

  final LedgerTransaction transaction;

  /// The line the amount belongs to: its own, or for a line to validate the
  /// identifier it will get once validated. What a module attaches to a
  /// line (kWh, a trip) uses it.
  final String ownLineId;

  /// The line whose category, period and answers the amount follows: its
  /// own, the one it will get once validated for a line to validate, or
  /// the expense's for an attached refund.
  final String lineId;

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
  /// With [until], only what was paid up to that day counts: the table that
  /// explains the wealth of the current year stops there (decision H8 of
  /// phase 5).
  YearViews(this.ledger, {this.until});

  final Ledger ledger;
  final CalendarDate? until;

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

  late final List<ViewLine> _flows = _buildFlows();

  List<ViewLine> _buildFlows() {
    final flows = <ViewLine>[];
    void add(
      LedgerTransaction t,
      String lineId,
      String? categoryId,
      int amount,
      CalendarDate start,
      CalendarDate end, {
      LedgerTransaction? of,
      String? own,
    }) {
      final year = (of ?? t).date.year;
      final tree = ledger.trees[year];
      final origin = categoryId == null ? null : tree?.byId[categoryId];
      flows.add(
        ViewLine._(
          transaction: t,
          ownLineId: own ?? lineId,
          lineId: lineId,
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
      if (until != null && t.date.isAfter(until!)) continue;
      if (!t.isValidated) {
        // A line to validate counts as its rules propose: category and
        // period (principle 3 of phase 3); without a proposal, unclassified.
        final proposal = ledger.proposalOf(t);
        if (proposal?.isTransfer ?? false) continue;
        final lineId = t.line?.id ?? Ledger.fallbackLineId(t.id);
        add(t, lineId, proposal?.categoryId, t.amount, proposal?.periodStart ?? t.date, proposal?.periodEnd ?? t.date);
        continue;
      }
      if (t.isTransfer) continue;
      if (t.lines.isEmpty) {
        add(t, Ledger.fallbackLineId(t.id), null, t.amount, t.date, t.date);
        continue;
      }
      var lines = 0;
      for (final line in t.lines) {
        lines += line.amount;
        // A refund attached to a validated expense follows it: category and
        // period (principle 5).
        if (ledger.refundedExpenseOf(t, line) case final expense?) {
          final paid = expense.line;
          add(
            t,
            paid.id,
            paid.categoryId,
            line.amount,
            paid.periodStart,
            paid.periodEnd,
            of: expense.transaction,
            own: line.id,
          );
          continue;
        }
        add(t, line.id, line.categoryId, line.amount, line.periodStart, line.periodEnd);
      }
      // A transaction counts for exactly its amount (step 5.0 of phase 5).
      // Only a merge can leave its lines adding up to another amount: the
      // amount corrected on one device, the line rewritten with the old one
      // on another. The difference is « Non classé », where it shows; saving
      // the transaction again writes both amounts.
      if (lines != t.amount) {
        add(t, Ledger.fallbackLineId(t.id), null, t.amount - lines, t.date, t.date, own: '${t.id}-gap');
      }
    }
    return flows;
  }

  // ------------------------------------------------------- read by modules

  /// Every amount the views count, as they classify and spread it (step
  /// 6.0 of phase 6): the modules read them and never classify again.
  List<ViewLine> get lines => List.unmodifiable(_flows);

  /// The lines that count in [categoryId] of [year], or anything below it,
  /// in the view [kind], with what each places there month by month,
  /// before any redistribution (decision H1 of phase 6), by payment date.
  /// A line counted in the year is listed even when its shares there round
  /// to zero. Empty when [categoryId] is not in the tree [year] is shown
  /// with.
  List<CategoryLine> linesIn(int year, ViewKind kind, String categoryId) {
    final tree = treeOf(year);
    if (tree == null || !tree.byId.containsKey(categoryId)) return const [];
    final subtree = tree.subtreeOf(categoryId);
    final months = <ViewLine, List<int>>{};
    _place(year, kind, tree, (flow, target, month, cents) {
      if (target is _InCategory && subtree.contains(target.id)) {
        (months[flow] ??= List.filled(12, 0))[month - 1] += cents;
      }
    });
    return [for (final e in months.entries) CategoryLine(e.key, MonthlyAmounts(e.value))]..sort(_byPayment);
  }

  /// The lines classified, in the tree of the year of their category (the
  /// payment year, or the expense's for an attached refund), in the
  /// category named [name] of that tree or anything below it, every year
  /// together, by payment date (decision H1 of phase 6).
  List<ViewLine> linesNamed(String name) {
    final subtrees = <int, Set<String>?>{};
    Set<String>? subtree(int year) => subtrees.putIfAbsent(year, () {
      final tree = ledger.trees[year];
      final named = tree?.named(name);
      return named == null ? null : tree!.subtreeOf(named.id);
    });
    return [
      for (final flow in _flows)
        if (flow.origin != null && (subtree(flow.originYear)?.contains(flow.origin!.id) ?? false)) flow,
    ]..sort((a, b) => _byPayment(CategoryLine(a, MonthlyAmounts.zero), CategoryLine(b, MonthlyAmounts.zero)));
  }

  static int _byPayment(CategoryLine a, CategoryLine b) {
    final byDate = a.line.paid.compareTo(b.line.paid);
    if (byDate != 0) return byDate;
    final byTransaction = a.line.transaction.id.compareTo(b.line.transaction.id);
    return byTransaction != 0 ? byTransaction : a.line.ownLineId.compareTo(b.line.ownLineId);
  }

  // ------------------------------------------------------------- placement

  /// The category of [year] that an amount of [flow] goes to (principle 3):
  /// its own category in the year of its payment; elsewhere the category of
  /// the same name, if it can hold transactions; otherwise the category of
  /// the answer given for its line and that year, while it holds
  /// ([answerOf]); otherwise « À classer ».
  _Target _target(ViewLine flow, int year, CategoryTree tree) {
    final origin = flow.origin!;
    if (year == flow.originYear) return _InCategory(origin.id);
    final match = _sameName.putIfAbsent((origin.id, year), () {
      final named = tree.named(origin.name);
      return named != null && tree.canHoldTransactions(named.id) ? named.id : null;
    });
    if (match != null) return _InCategory(match);
    final answer = _answer(flow.lineId, origin.id, year, tree);
    if (answer != null) return _InCategory(answer.categoryId);
    return _ToClassify(flow.nature!);
  }

  ShareClassification? _answer(String lineId, String originId, int year, CategoryTree tree) {
    final answer = ledger.shareClassifications[(lineId, year)];
    if (answer == null || answer.originCategoryId != originId || !tree.canHoldTransactions(answer.categoryId)) {
      return null;
    }
    return answer;
  }

  /// The answer given for the shares of [lineId] in [year], while it holds:
  /// the line still has the category it was given for, and the category
  /// chosen can hold transactions in the tree of the year (decision H5).
  ShareClassification? answerOf(String lineId, int year) {
    final tree = treeOf(year);
    final origin = originOf(lineId);
    if (tree == null || origin == null) return null;
    return _answer(lineId, origin.id, year, tree);
  }

  /// The category of the line [lineId] that its shares in other years are
  /// matched from, in the tree of its payment year; null when it has none.
  Category? originOf(String lineId) => _origins[lineId];

  late final Map<String, Category> _origins = {
    for (final flow in _flows)
      if (flow.origin != null) flow.lineId: flow.origin!,
  };

  /// The transaction whose line is [lineId], and the year of the tree of its
  /// category.
  LedgerTransaction? transactionOfLine(String lineId) => _lineTransactions[lineId];

  late final Map<String, LedgerTransaction> _lineTransactions = {
    for (final t in ledger.transactions.values) ...{
      Ledger.fallbackLineId(t.id): t,
      for (final line in t.lines) line.id: t,
    },
  };

  /// The questions waiting for an answer (decision H5): every line with
  /// amounts in « À classer » of a year shown, in either view, grouped by
  /// category of origin and year, years then names in order.
  late final List<PendingShareGroup> pendingShares = _pendingShares();

  List<PendingShareGroup> _pendingShares() {
    final first = firstYear;
    if (first == null) return const [];
    final groups = <(String, int), Map<String, (int, int)>>{};
    final origins = <(String, int), (Category, int, CategoryNature)>{};
    void add(ViewLine flow, int year, int economic, int cash) {
      final key = (flow.origin!.id, year);
      origins[key] = (flow.origin!, flow.originYear, flow.nature!);
      final shares = groups.putIfAbsent(key, () => {});
      final (e, c) = shares[flow.lineId] ?? (0, 0);
      shares[flow.lineId] = (e + economic, c + cash);
    }

    // Only the amounts that fall in another year than the one of their
    // category can be « À classer »: one pass over the flows, the same
    // placement as the views.
    for (final flow in _flows) {
      if (flow.origin == null) continue;
      final own = flow.originYear;
      if (flow.start.year == own && flow.end.year == own && flow.paid.year == own) continue;
      final targets = <int, _Target>{};
      _Target target(int year) => targets.putIfAbsent(year, () => _target(flow, year, treeOf(year)!));
      for (final (year, _, cents) in flow.shares) {
        if (year != own && year >= first && target(year) is _ToClassify) add(flow, year, cents, 0);
      }
      final paid = flow.paid.year;
      if (paid != own && paid >= first && target(paid) is _ToClassify) add(flow, paid, 0, flow.amount);
    }
    final result = [
      for (final MapEntry(key: key, value: shares) in groups.entries)
        PendingShareGroup(
          origin: origins[key]!.$1,
          originYear: origins[key]!.$2,
          nature: origins[key]!.$3,
          year: key.$2,
          shares:
              [
                for (final MapEntry(key: lineId, value: (economic, cash)) in shares.entries)
                  PendingShare(lineId: lineId, transaction: transactionOfLine(lineId)!, economic: economic, cash: cash),
              ]..sort((a, b) {
                final byDate = a.transaction.date.compareTo(b.transaction.date);
                return byDate != 0 ? byDate : a.lineId.compareTo(b.lineId);
              }),
        ),
    ];
    return result..sort((a, b) {
      if (a.year != b.year) return a.year.compareTo(b.year);
      if (a.originYear != b.originYear) return a.originYear.compareTo(b.originYear);
      final byName = normalizeName(a.origin.name).compareTo(normalizeName(b.origin.name));
      return byName != 0 ? byName : a.origin.id.compareTo(b.origin.id);
    });
  }

  final _sameName = <(String, int), String?>{};

  /// Gives every amount that falls in [year] in the view [kind] to [sink],
  /// with its target and its month.
  void _place(
    int year,
    ViewKind kind,
    CategoryTree tree,
    void Function(ViewLine flow, _Target target, int month, int cents) sink,
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
