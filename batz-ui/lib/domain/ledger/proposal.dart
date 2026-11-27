import 'package:equatable/equatable.dart';

import '../calendar_date.dart';
import 'rule.dart';
import 'transaction.dart';

/// How a line is classified: in a category with a period, as a transfer
/// with another account (which has no category and no period), or split
/// between several categories, each line with its amount and period (only
/// the user splits: rules never do).
class Classification extends Equatable {
  const Classification.category(this.categoryId, {required this.periodStart, required this.periodEnd})
    : counterpartAccountId = null,
      lines = const [];

  const Classification.transfer(this.counterpartAccountId)
    : categoryId = null,
      periodStart = null,
      periodEnd = null,
      lines = const [];

  const Classification.split(this.lines)
    : categoryId = null,
      counterpartAccountId = null,
      periodStart = null,
      periodEnd = null;

  final String? categoryId;
  final String? counterpartAccountId;
  final CalendarDate? periodStart;
  final CalendarDate? periodEnd;

  /// The lines of a split classification, adding up to the amount.
  final List<LineDraft> lines;

  bool get isTransfer => counterpartAccountId != null;

  bool get isSplit => lines.isNotEmpty;

  @override
  List<Object?> get props => [categoryId, counterpartAccountId, periodStart, periodEnd, lines];
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

/// The line is the other side of a transfer between two detailed accounts:
/// the line [otherId] of the other account went the other way, for the
/// same amount, a few days apart (see transfer_pairs.dart). The line is «
/// proposée » as a transfer with that account, whatever its rules say.
class PairedTransfer extends RuleOutcome {
  const PairedTransfer(this.otherId, this.classification);

  final String otherId;

  /// The transfer with the account of [otherId].
  final Classification classification;

  @override
  List<Object?> get props => [otherId, classification];
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

/// The outcome of [rules] for a line of raw text [rawText]: the rules whose
/// matching line has the most terms win. [classify] turns the winning rule
/// into its classification, or null when its target is unusable.
RuleOutcome outcomeOf(String rawText, Iterable<MappingRule> rules, Classification? Function(MappingRule) classify) {
  final text = normalizeText(rawText);
  var best = 0;
  final winners = <MappingRule>[];
  for (final rule in rules) {
    final weight = rule.weightFor(text);
    if (weight == 0) continue;
    if (weight > best) {
      best = weight;
      winners.clear();
    }
    if (weight == best) winners.add(rule);
  }
  if (winners.isEmpty) return const NoRule();
  winners.sort((a, b) => a.id.compareTo(b.id));
  if (winners.map((r) => r.result).toSet().length > 1) return Conflict(winners);
  final classification = classify(winners.first);
  return classification == null ? UnusableRule(winners.first) : Proposed(winners.first, classification);
}
