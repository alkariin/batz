import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ledger/category.dart';
import '../../domain/views/wealth.dart';
import '../../domain/views/year_view.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../shell.dart';
import '../wealth/wealth_page.dart';
import '../year/year_page.dart';
import '../year/year_texts.dart';

/// The key figures of the current year on the home screen: income, expenses
/// and savings in the economic view, with access to the « Année » screen;
/// and the net wealth of the day, with access to « Fortune ». Nothing while
/// there is neither.
class KeyFiguresCard extends StatelessWidget {
  const KeyFiguresCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = context.read<AppServices>().today();
    final year = today.year;
    final view = context.select<LedgerCubit, YearView?>((c) => c.state.ledger.views.of(year, ViewKind.economic));
    final net = context.select<LedgerCubit, int?>((c) {
      final wealth = c.state.ledger.wealth(today);
      return wealth.years.isEmpty ? null : wealth.fortuneAt(today);
    });
    if (view == null && net == null) return const SizedBox.shrink();
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
    Widget open(String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        Icon(Icons.chevron_right, color: theme.colorScheme.primary),
      ],
    );
    return Card(
      key: const Key('keyFigures'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (view != null)
            InkWell(
              onTap: () => openYear(context, year),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(l.keyFiguresTitle('$year'), style: theme.textTheme.titleMedium)),
                        open(l.keyFiguresOpen),
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
          if (view != null && net != null) const Divider(height: 1),
          if (net != null)
            InkWell(
              key: const Key('keyWealthOpen'),
              onTap: () => openWealth(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [figure('keyWealth', l.keyFiguresWealth, formatAmount(net)), open(l.keyFiguresWealthOpen)],
                ),
              ),
            ),
        ],
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

  /// Shows the « Fortune » section of the shell, or the screen on its own.
  static void openWealth(BuildContext context) {
    final shell = ShellScope.maybeOf(context);
    if (shell != null) {
      shell.select(Section.wealth);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WealthPage()));
  }
}
