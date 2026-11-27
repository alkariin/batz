import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/modules/monthly_tasks.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import 'monthly_tasks_page.dart';
import 'monthly_widgets.dart';

/// Every month of the follow-up, the most recent first, each with its boxes:
/// a month finished is folded.
class MonthlyPage extends StatelessWidget {
  const MonthlyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = context.read<AppServices>().today();
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final months = ledger.monthlyStatuses(today);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.monthlyTitle),
        actions: [
          IconButton(
            key: const Key('monthlyEdit'),
            tooltip: l.monthlyEdit,
            icon: const Icon(Icons.edit_note),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MonthlyTasksPage())),
          ),
        ],
      ),
      body: months.isEmpty
          ? ListView(padding: const EdgeInsets.all(16), children: [Text(l.monthlyEmpty)])
          : ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              children: [
                for (final month in months)
                  Card(
                    child: ExpansionTile(
                      key: ValueKey('month-${month.month}'),
                      initiallyExpanded: !month.complete,
                      leading: Icon(month.complete ? Icons.check_circle : Icons.radio_button_unchecked),
                      title: Text(monthTitle(l, month.month, monthOf(today))),
                      subtitle: Text(monthProgress(l, month)),
                      children: [for (final status in month.tasks) monthTaskTile(context, month.month, status)],
                    ),
                  ),
              ],
            ),
    );
  }
}
