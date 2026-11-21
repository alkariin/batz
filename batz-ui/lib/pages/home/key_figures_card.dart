import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/calendar_date.dart';
import '../../domain/ledger/category.dart';
import '../../domain/views/year_view.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../shell.dart';
import '../year/year_page.dart';
import '../year/year_texts.dart';

/// The key figures of the current year on the home screen (decision H8):
/// income, expenses and savings in the economic view, with access to the
/// « Année » screen. Nothing while the year has no tree to show.
class KeyFiguresCard extends StatelessWidget {
  const KeyFiguresCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final year = CalendarDate.today().year;
    final view = context.select<LedgerCubit, YearView?>((c) => c.state.ledger.views.of(year, ViewKind.economic));
    if (view == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    Widget figure(String key, String label, String amount) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          Text(amount, key: ValueKey(key), style: theme.textTheme.titleMedium),
        ],
      ),
    );
    return Card(
      key: const Key('keyFigures'),
      child: InkWell(
        onTap: () => openYear(context, year),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l.keyFiguresTitle('$year'), style: theme.textTheme.titleMedium)),
                  Text(l.keyFiguresOpen, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                  Icon(Icons.chevron_right, color: theme.colorScheme.primary),
                ],
              ),
              Text(l.keyFiguresHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  figure('keyIncome', l.yearIncome, shownAmount(view.income.total, CategoryNature.income)),
                  figure('keyExpenses', l.yearExpenses, shownAmount(view.expenses.total, CategoryNature.expense)),
                  figure('keySavings', l.yearSavings, formatAmount(view.savings.total)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows the « Année » section of the shell, or the screen on its own.
  static void openYear(BuildContext context, int year) {
    final shell = ShellScope.maybeOf(context);
    if (shell != null) {
      shell.select(Section.year);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => YearPage(initialYear: year)));
  }
}
