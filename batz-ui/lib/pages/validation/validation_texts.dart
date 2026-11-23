import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/proposal.dart';
import '../../domain/ledger/rule.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';

/// The lines of [rule], as the user wrote them, joined by « OU ».
String keywordsText(AppLocalizations l, MappingRule rule) => rule.lines.join(l.rulesOr);

/// Where [rule] classifies: its category, or the account of the transfer.
String ruleTargetText(AppLocalizations l, Ledger ledger, MappingRule rule) {
  if (rule.targetAccountId case final account?) {
    return l.validationTransferWith(ledger.accounts[account]?.name ?? '?');
  }
  final category = ledger.categories[rule.targetCategoryId];
  return category?.name ?? '?';
}

/// A classification in a few words: the category and its period, or the
/// transfer.
String classificationText(AppLocalizations l, Ledger ledger, Classification c) {
  if (c.counterpartAccountId case final account?) {
    return l.validationTransferWith(ledger.accounts[account]?.name ?? '?');
  }
  final name = ledger.categories[c.categoryId]?.name ?? '?';
  final start = c.periodStart!, end = c.periodEnd!;
  if (start == end) return name;
  return '$name · ${formatDate(start.toDateTime())} – ${formatDate(end.toDateTime())}';
}
