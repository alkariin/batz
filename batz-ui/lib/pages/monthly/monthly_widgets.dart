import 'package:flutter/material.dart';

import '../../domain/allocation.dart';
import '../../domain/modules/monthly_tasks.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_texts.dart';

/// The name of [month] (1 to 12), `novembre`.
String fullMonthName(AppLocalizations l, int month) => l.monthlyMonthNames.split(',')[month - 1];

/// [month] as a title: `Novembre 2026`, or `Novembre 2026, en cours` for the
/// month of [today].
String monthTitle(AppLocalizations l, YearMonth month, YearMonth today) {
  final name = fullMonthName(l, month.month);
  final text = '${name[0].toUpperCase()}${name.substring(1)} ${month.year}';
  return month == today ? l.monthlyCurrent(text) : text;
}

/// How far a month is: `2 sur 4`, or `Terminé`.
String monthProgress(AppLocalizations l, MonthStatus month) =>
    month.complete ? l.monthlyComplete : l.monthlyProgress(month.doneCount, month.tasks.length);

/// A task of a month as a box: the user checks it, unless the imports of
/// its account did.
Widget monthTaskTile(BuildContext context, YearMonth month, MonthlyTaskStatus status) {
  final l = AppLocalizations.of(context);
  final until = status.coveredUntil;
  final subtitle = status.task.accountId == null
      ? null
      : until == null
      ? l.monthlyNotImported
      : l.monthlyImported(formatDate(until.toDateTime()));
  return CheckboxListTile(
    key: ValueKey('monthly-${status.task.id}-$month'),
    dense: true,
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(status.task.name),
    subtitle: subtitle == null ? null : Text(subtitle),
    value: status.done,
    // Checked by the imports: nothing to undo by hand.
    onChanged: status.state == MonthlyTaskState.imported
        ? null
        : (done) => applyToLedger(context, (ledger) => ledger.setMonthlyCheck(status.task.id, month, done: done!)),
  );
}
