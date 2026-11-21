import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/proposal.dart';
import '../../domain/ledger/rule.dart';
import '../../domain/period_model.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';

/// The keywords of [rule], as the user wrote them.
String keywordsText(MappingRule rule) => rule.keywords.join(', ');

/// Where [rule] classifies: its category, or the account of the transfer.
String ruleTargetText(AppLocalizations l, Ledger ledger, MappingRule rule) {
  if (rule.targetAccountId case final account?) {
    return l.validationTransferWith(ledger.accounts[account]?.name ?? '?');
  }
  final category = ledger.categories[rule.targetCategoryId];
  return category?.name ?? '?';
}

String periodModelText(AppLocalizations l, PeriodModel? model, int? months) => switch (model) {
  null => l.rulePeriodNone,
  PeriodModel.previousMonth => l.rulePeriodPreviousMonth,
  PeriodModel.nextMonth => l.rulePeriodNextMonth,
  PeriodModel.monthsAfter => l.rulePeriodMonthsAfter.replaceFirst('N', '${months ?? 'N'}'),
  PeriodModel.monthsBefore => l.rulePeriodMonthsBefore.replaceFirst('N', '${months ?? 'N'}'),
  PeriodModel.currentYear => l.rulePeriodCurrentYear,
  PeriodModel.previousYear => l.rulePeriodPreviousYear,
};

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
