import 'package:equatable/equatable.dart';

import '../ids.dart';
import '../journal/journal_entry.dart';
import 'category.dart';
import 'ledger.dart';
import 'ledger_exception.dart';

/// Journal entity and fields of a redistribution rule of a
/// year.
abstract final class RedistributionFields {
  static const entity = 'redistribution';
  static const year = 'year';
  static const sourceCategoryId = 'sourceCategoryId';
  static const targetCategoryId = 'targetCategoryId';

  /// The percentage in hundredths of a percent, an integer: 1000 is 10 %,
  /// 3333 is 33.33 %. Null for a rule of a fixed amount.
  static const basisPoints = 'basisPoints';

  /// The fixed amount taken from each payment of the source, in cents, more
  /// than zero. Null for a rule of a percentage.
  static const amount = 'amount';
}

/// 100 %, in hundredths of a percent.
const fullBasisPoints = 10000;

/// A redistribution rule: what leaves [sourceId] and joins [targetId], on
/// a line of its own on each side. Either a percentage: month by month,
/// [basisPoints] of what the source shows; or a fixed amount: [amount] of
/// each payment classified in the source (a rent that includes the charges
/// and the parking space).
class RedistributionRule extends Equatable {
  const RedistributionRule({
    required this.id,
    required this.year,
    required this.sourceId,
    required this.targetId,
    this.basisPoints,
    this.amount,
  });

  final String id;
  final int year;
  final String sourceId;
  final String targetId;

  /// Exactly one of [basisPoints] and [amount] is set; a merge of two
  /// devices can leave both or neither, and the rule does not apply.
  final int? basisPoints;

  /// In cents.
  final int? amount;

  bool get isFixed => amount != null && basisPoints == null;

  bool get isPercentage => basisPoints != null && amount == null;

  @override
  List<Object?> get props => [id, year, sourceId, targetId, basisPoints, amount];
}

/// What the user enters to create or modify a redistribution rule: a
/// percentage or a fixed amount.
class RedistributionDraft {
  const RedistributionDraft({
    required this.year,
    required this.sourceId,
    required this.targetId,
    this.basisPoints,
    this.amount,
  });

  final int year;
  final String sourceId;
  final String targetId;
  final int? basisPoints;
  final int? amount;
}

/// Identifier of the copy, in [year], of the redistribution rule [sourceId]:
/// computed like the copies of categories, which the rules follow.
String copiedRedistributionId(String sourceId, int year) => derivedId('redistribution-copy/$sourceId/$year');

/// Why a redistribution rule does not apply: it stays, and is listed in the
/// tasks.
enum RedistributionProblem {
  /// The source is not a category of the year's tree: deleted, detached,
  /// or of another year.
  sourceMissing,
  targetMissing,

  /// The source has children, or is a top-level group.
  sourceNotLeaf,
  targetNotLeaf,

  /// Source and target are the same category.
  sameCategory,

  /// One is an income, the other an expense.
  natureMismatch,

  /// The percentage is not between 0.01 and 100.
  percentInvalid,

  /// The fixed amount is not more than zero.
  amountInvalid,

  /// The rule has both a percentage and a fixed amount, or neither (after a
  /// merge).
  percentOrAmount,

  /// The percentages from this source add up to more than 100 % (after a
  /// merge): all of them are left aside.
  overHundred,

  /// The target of one rule is the source of another (after a merge): both
  /// are left aside.
  chain,
}

/// A rule of a year that does not apply, and why.
class InapplicableRedistribution extends Equatable {
  const InapplicableRedistribution(this.rule, this.problem);

  final RedistributionRule rule;
  final RedistributionProblem problem;

  @override
  List<Object?> get props => [rule, problem];
}

/// [cents] × [basisPoints] ÷ 10 000, rounded to the cent, halves away from
/// zero.
int redistributedCents(int cents, int basisPoints) {
  final product = cents.abs() * basisPoints;
  final rounded = (product * 2 + fullBasisPoints) ~/ (2 * fullBasisPoints);
  return cents < 0 ? -rounded : rounded;
}

/// The problem of each rule of [rules] in [tree], null for a rule that
/// applies. The checks of each rule come first; only the rules that pass
/// them are compared with each other (over 100 %, chains).
Map<String, RedistributionProblem?> redistributionProblems(List<RedistributionRule> rules, CategoryTree tree) {
  final problems = <String, RedistributionProblem?>{};
  for (final rule in rules) {
    problems[rule.id] = switch (rule) {
      _ when !tree.byId.containsKey(rule.sourceId) => RedistributionProblem.sourceMissing,
      _ when !tree.byId.containsKey(rule.targetId) => RedistributionProblem.targetMissing,
      _ when rule.sourceId == rule.targetId => RedistributionProblem.sameCategory,
      _ when !tree.canHoldTransactions(rule.sourceId) => RedistributionProblem.sourceNotLeaf,
      _ when !tree.canHoldTransactions(rule.targetId) => RedistributionProblem.targetNotLeaf,
      _ when tree.natureOf(rule.sourceId) != tree.natureOf(rule.targetId) => RedistributionProblem.natureMismatch,
      _ when !rule.isFixed && !rule.isPercentage => RedistributionProblem.percentOrAmount,
      RedistributionRule(:final basisPoints?) when basisPoints < 1 || basisPoints > fullBasisPoints =>
        RedistributionProblem.percentInvalid,
      RedistributionRule(:final amount?) when amount < 1 => RedistributionProblem.amountInvalid,
      _ => null,
    };
  }
  final valid = [
    for (final rule in rules)
      if (problems[rule.id] == null) rule,
  ];
  final bySource = <String, int>{};
  for (final rule in valid) {
    bySource[rule.sourceId] = (bySource[rule.sourceId] ?? 0) + (rule.basisPoints ?? 0);
  }
  final sources = {for (final r in valid) r.sourceId}, targets = {for (final r in valid) r.targetId};
  for (final rule in valid) {
    if (bySource[rule.sourceId]! > fullBasisPoints) {
      problems[rule.id] = RedistributionProblem.overHundred;
    } else if (sources.contains(rule.targetId) || targets.contains(rule.sourceId)) {
      problems[rule.id] = RedistributionProblem.chain;
    }
  }
  return problems;
}

/// The redistribution rules of a [Ledger] and their operations, apart from
/// the ledger's core.
extension RedistributionOperations on Ledger {
  /// The rules of [year], by source then target name. For a year without a
  /// tree that an earlier year will be copied to, the rules the copy will
  /// write, with their computed identifiers.
  List<RedistributionRule> redistributionsOf(int year) {
    final tree = trees[year];
    if (tree == null) {
      final source = sourceYearFor(year);
      return [
        if (source != null)
          for (final r in redistributionsOf(source))
            RedistributionRule(
              id: copiedRedistributionId(r.id, year),
              year: year,
              sourceId: copiedCategoryId(r.sourceId, year),
              targetId: copiedCategoryId(r.targetId, year),
              basisPoints: r.basisPoints,
              amount: r.amount,
            ),
      ];
    }
    String name(String id) => normalizeName(tree.byId[id]?.name ?? '');
    return [
      for (final r in redistributions.values)
        if (r.year == year) r,
    ]..sort((a, b) {
      for (final order in [
        name(a.sourceId).compareTo(name(b.sourceId)),
        name(a.targetId).compareTo(name(b.targetId)),
        a.id.compareTo(b.id),
      ]) {
        if (order != 0) return order;
      }
      return 0;
    });
  }

  /// The rules of the years that have a tree which do not apply, by
  /// year: listed in the tasks.
  List<InapplicableRedistribution> get inapplicableRedistributions {
    final result = <InapplicableRedistribution>[];
    for (final year in yearsWithTree) {
      final rules = redistributionsOf(year);
      final problems = redistributionProblems(rules, trees[year]!);
      for (final rule in rules) {
        if (problems[rule.id] case final problem?) result.add(InapplicableRedistribution(rule, problem));
      }
    }
    return result;
  }

  /// Creates the rule [id]. Refused, with its reason: without a tree for
  /// the year; when source and target are the same, are not both categories
  /// without children of the year, or are not of the same nature; without
  /// exactly one of a percentage and a fixed amount; with a percentage out
  /// of 0.01 to 100 %, or a fixed amount of zero or less; when a rule from
  /// the same source to the same target exists; when the target is the
  /// source of another rule or the source the target of one; when the
  /// percentages from the source would exceed 100 %
  /// ([LedgerException.count] is that total).
  Modification createRedistribution(String id, RedistributionDraft draft) =>
      Modification.set(RedistributionFields.entity, id, _redistributionFields(draft, replacing: null));

  /// Modifies the rule [id] under the same rules; its year cannot change.
  Modification updateRedistribution(String id, RedistributionDraft draft) {
    final rule = redistributions[id];
    if (rule == null || rule.year != draft.year) throw const LedgerException(LedgerError.unknownRedistribution);
    return Modification.set(RedistributionFields.entity, id, _redistributionFields(draft, replacing: id));
  }

  Modification deleteRedistribution(String id) {
    if (!redistributions.containsKey(id)) throw const LedgerException(LedgerError.unknownRedistribution);
    return Modification.delete(RedistributionFields.entity, id);
  }

  Map<String, Object?> _redistributionFields(RedistributionDraft draft, {required String? replacing}) {
    final tree = trees[draft.year];
    if (tree == null) throw const LedgerException(LedgerError.noTree);
    final source = draft.sourceId, target = draft.targetId;
    if (source == target) throw const LedgerException(LedgerError.redistributionSameCategory);
    if (!tree.canHoldTransactions(source) || !tree.canHoldTransactions(target)) {
      throw const LedgerException(LedgerError.redistributionNotLeaf);
    }
    if (tree.natureOf(source) != tree.natureOf(target)) {
      throw const LedgerException(LedgerError.redistributionNatureMismatch);
    }
    final basisPoints = draft.basisPoints, amount = draft.amount;
    if ((basisPoints == null) == (amount == null)) {
      throw const LedgerException(LedgerError.redistributionPercentOrAmount);
    }
    if (basisPoints != null && (basisPoints < 1 || basisPoints > fullBasisPoints)) {
      throw const LedgerException(LedgerError.redistributionPercentInvalid);
    }
    if (amount != null && amount < 1) throw const LedgerException(LedgerError.redistributionAmountInvalid);
    final others = [
      for (final r in redistributionsOf(draft.year))
        if (r.id != replacing) r,
    ];
    if (others.any((r) => r.sourceId == source && r.targetId == target)) {
      throw const LedgerException(LedgerError.redistributionDuplicate);
    }
    if (others.any((r) => r.sourceId == target)) throw const LedgerException(LedgerError.redistributionTargetIsSource);
    if (others.any((r) => r.targetId == source)) throw const LedgerException(LedgerError.redistributionSourceIsTarget);
    if (basisPoints != null) {
      final total = others.where((r) => r.sourceId == source).fold(basisPoints, (sum, r) => sum + (r.basisPoints ?? 0));
      if (total > fullBasisPoints) throw LedgerException(LedgerError.redistributionOverHundred, count: total);
    }
    return {
      RedistributionFields.year: draft.year,
      RedistributionFields.sourceCategoryId: source,
      RedistributionFields.targetCategoryId: target,
      RedistributionFields.basisPoints: basisPoints,
      RedistributionFields.amount: amount,
    };
  }
}
