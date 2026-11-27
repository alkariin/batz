import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/modules/monthly_tasks.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import 'monthly_page.dart';
import 'monthly_tasks_page.dart';
import 'monthly_widgets.dart';

/// The monthly follow-up on the home screen: the month to finish (the oldest
/// past month with a task to do, or else the current one) and its boxes.
class MonthlyCard extends StatelessWidget {
  const MonthlyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = context.read<AppServices>().today();
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final month = ledger.monthToFinish(today);
    final theme = Theme.of(context);
    if (month == null) {
      return Card(
        child: ListTile(
          key: const Key('monthlySetUp'),
          leading: const Icon(Icons.checklist),
          title: Text(l.monthlyTitle),
          subtitle: Text(l.monthlyEmpty),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MonthlyTasksPage())),
        ),
      );
    }
    return Card(
      key: const Key('monthlyCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(l.monthlyTitle, style: theme.textTheme.titleMedium),
            subtitle: Text(
              '${monthTitle(l, month.month, monthOf(today))} · ${monthProgress(l, month)}',
              key: const Key('monthlyCardMonth'),
            ),
          ),
          for (final status in month.tasks) monthTaskTile(context, month.month, status),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('monthlyAll'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MonthlyPage())),
              child: Text(l.monthlyAll),
            ),
          ),
        ],
      ),
    );
  }
}
