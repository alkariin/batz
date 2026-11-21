import 'package:equatable/equatable.dart';

import '../calendar_date.dart';
import 'rule.dart';

/// How a line is classified: in a category with a period, or as a transfer
/// with another account (which has no category and no period).
class Classification extends Equatable {
  const Classification.category(this.categoryId, {required this.periodStart, required this.periodEnd})
    : counterpartAccountId = null;

  const Classification.transfer(this.counterpartAccountId) : categoryId = null, periodStart = null, periodEnd = null;

  final String? categoryId;
  final String? counterpartAccountId;
  final CalendarDate? periodStart;
  final CalendarDate? periodEnd;

  bool get isTransfer => counterpartAccountId != null;

  @override
  List<Object?> get props => [categoryId, counterpartAccountId, periodStart, periodEnd];
}

/// What the rules of its year say of a line to validate: computed at
/// each load, never stored.
sealed class RuleOutcome extends Equatable {
  const RuleOutcome();
}

/// No rule matches: the line is « à compléter ».
class NoRule extends RuleOutcome {
  const NoRule();

  @override
  List<Object?> get props => [];
}

/// One result wins: the line is « proposée ». [rule] is the rule that gives
/// it (the first by identifier when several equal rules agree).
class Proposed extends RuleOutcome {
  const Proposed(this.rule, this.classification);

  final MappingRule rule;
  final Classification classification;

  @override
  List<Object?> get props => [rule, classification];
}

/// Rules of equal weight give different results: the line is « à compléter
/// », with the rules in competition.
class Conflict extends RuleOutcome {
  const Conflict(this.rules);

  /// At least two, by identifier.
  final List<MappingRule> rules;

  @override
  List<Object?> get props => [rules];
}

/// The winning rule targets a category or an account that can no longer be
/// used: it proposes nothing, the line is « à compléter », and the rule is
/// listed in the tasks.
class UnusableRule extends RuleOutcome {
  const UnusableRule(this.rule);

  final MappingRule rule;

  @override
  List<Object?> get props => [rule];
}

/// The outcome of [rules] for a line of raw text [rawText]: the rules that
/// match and have the most keywords win. [classify] turns the winning rule
/// into its classification, or null when its target is unusable.
RuleOutcome outcomeOf(String rawText, Iterable<MappingRule> rules, Classification? Function(MappingRule) classify) {
  final text = normalizeText(rawText);
  var best = 0;
  final winners = <MappingRule>[];
  for (final rule in rules) {
    if (!rule.matches(text)) continue;
    if (rule.weight > best) {
      best = rule.weight;
      winners.clear();
    }
    if (rule.weight == best) winners.add(rule);
  }
  if (winners.isEmpty) return const NoRule();
  winners.sort((a, b) => a.id.compareTo(b.id));
  if (winners.map((r) => r.result).toSet().length > 1) return Conflict(winners);
  final classification = classify(winners.first);
  return classification == null ? UnusableRule(winners.first) : Proposed(winners.first, classification);
}
