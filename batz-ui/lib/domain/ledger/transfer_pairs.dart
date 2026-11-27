import '../calendar_date.dart';
import 'ledger.dart';
import 'proposal.dart';
import 'transaction.dart';

/// The most days between the two lines of a transfer between two detailed
/// accounts: the time a bank transfer takes, weekends included.
const pairWindowDays = 7;

/// A transfer between two detailed accounts appears on both: once in the
/// statement of each, each line a transfer to the other account. Each
/// account counts its own line; neither counts the other's as its
/// counterpart, otherwise the money would arrive twice.
///
/// The two lines are paired, at each load, never stored: a line that is a
/// transfer (validated, or proposed by its rules) from detailed account A to
/// detailed account B takes, on B, the unpaired line of the opposite amount
/// closest in date, at most [pairWindowDays] days apart, that is a
/// transfer to A, or a line to validate that no rule sends to another
/// account. Lines are taken by date, then identifier: every device pairs
/// the same lines. [ruleOutcomes] are what the rules say of each line to
/// validate. Returns both directions: each line to the other.
Map<String, String> pairTransfers(Ledger ledger, Map<String, RuleOutcome> ruleOutcomes) {
  String? counterpartOf(LedgerTransaction t) => t.isValidated
      ? t.counterpartAccountId
      : switch (ruleOutcomes[t.id]) {
          Proposed(:final classification) when classification.isTransfer => classification.counterpartAccountId,
          _ => null,
        };
  bool detailed(String? accountId) => ledger.accounts[accountId]?.isDetailed ?? false;

  final sides = <LedgerTransaction>[];
  final byAccountAndAmount = <(String, int), List<LedgerTransaction>>{};
  for (final t in ledger.transactions.values) {
    if (!t.isImported || t.amount == 0 || !detailed(t.accountId)) continue;
    (byAccountAndAmount[(t.accountId, t.amount)] ??= []).add(t);
    final counterpart = counterpartOf(t);
    if (counterpart != null && counterpart != t.accountId && detailed(counterpart)) sides.add(t);
  }
  sides.sort(_byDateThenId);

  final pairs = <String, String>{};
  for (final a in sides) {
    if (pairs.containsKey(a.id)) continue;
    LedgerTransaction? best;
    var bestGap = 0;
    for (final b in byAccountAndAmount[(counterpartOf(a)!, -a.amount)] ?? const <LedgerTransaction>[]) {
      if (pairs.containsKey(b.id)) continue;
      final counterpart = counterpartOf(b);
      final fits = counterpart == a.accountId || (!b.isValidated && counterpart == null);
      final gap = daysBetween(a.date, b.date).abs();
      if (!fits || gap > pairWindowDays) continue;
      if (best == null || gap < bestGap || (gap == bestGap && _byDateThenId(b, best) < 0)) {
        best = b;
        bestGap = gap;
      }
    }
    if (best != null) {
      pairs[a.id] = best.id;
      pairs[best.id] = a.id;
    }
  }
  return pairs;
}

int _byDateThenId(LedgerTransaction a, LedgerTransaction b) {
  final byDate = a.date.compareTo(b.date);
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

/// The days from [a] to [b], negative when [b] comes first.
int daysBetween(CalendarDate a, CalendarDate b) => b.toDateTime().difference(a.toDateTime()).inDays;
