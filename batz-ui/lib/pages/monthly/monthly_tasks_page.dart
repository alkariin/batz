import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/allocation.dart';
import '../../domain/ids.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/modules/monthly_tasks.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import 'monthly_widgets.dart';

/// The tasks of each month, in their order: added, modified, moved,
/// deleted. Without any, a first list is proposed: one import per detailed
/// account, the cash, the debts.
class MonthlyTasksPage extends StatelessWidget {
  const MonthlyTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final tasks = ledger.monthlyTasks;
    return Scaffold(
      appBar: AppBar(title: Text(l.monthlyEdit)),
      floatingActionButton: FloatingActionButton(
        key: const Key('monthlyTaskAdd'),
        tooltip: l.monthlyTaskNew,
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          if (tasks.isEmpty) ...[
            Padding(padding: const EdgeInsets.all(16), child: Text(l.monthlyEmpty)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                key: const Key('monthlySuggest'),
                icon: const Icon(Icons.playlist_add),
                label: Text(l.monthlySuggest),
                onPressed: () => applyToLedger(
                  context,
                  (ledger) => ledger.createSuggestedMonthlyTasks(
                    context.read<AppServices>().today(),
                    importName: l.monthlySuggestImport,
                    cashName: l.monthlySuggestCash,
                    debtsName: l.monthlySuggestDebts,
                  ),
                ),
              ),
            ),
          ],
          for (final (index, task) in tasks.indexed)
            ListTile(
              key: ValueKey('monthlyTask-${task.id}'),
              title: Text(task.name),
              subtitle: Text(
                l.monthlyTaskSummary(
                  '${fullMonthName(l, task.since.month)} ${task.since.year}',
                  task.accountId == null
                      ? l.monthlyTaskByHand
                      : l.monthlyTaskByImports(ledger.accounts[task.accountId]?.name ?? '?'),
                ),
              ),
              onTap: () => _edit(context, task),
              trailing: PopupMenuButton<String>(
                key: ValueKey('monthlyTaskMenu-${task.id}'),
                onSelected: (action) => switch (action) {
                  'up' => applyToLedger(context, (ledger) => ledger.moveMonthlyTask(task.id, -1)),
                  'down' => applyToLedger(context, (ledger) => ledger.moveMonthlyTask(task.id, 1)),
                  _ => _delete(context, task),
                },
                itemBuilder: (_) => [
                  if (index > 0) PopupMenuItem(value: 'up', child: Text(l.categoryMoveUp)),
                  if (index < tasks.length - 1) PopupMenuItem(value: 'down', child: Text(l.categoryMoveDown)),
                  PopupMenuItem(value: 'delete', child: Text(l.delete)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, MonthlyTask? task) async {
    final ledger = context.read<LedgerCubit>().state.ledger;
    final today = context.read<AppServices>().today();
    final draft = await showDialog<MonthlyTaskDraft>(
      context: context,
      builder: (_) => _TaskDialog(ledger: ledger, task: task, today: YearMonth(today.year, today.month)),
    );
    if (draft == null || !context.mounted) return;
    await applyToLedger(
      context,
      (ledger) => task == null ? ledger.createMonthlyTask(newId(), draft) : ledger.updateMonthlyTask(task.id, draft),
    );
  }

  Future<void> _delete(BuildContext context, MonthlyTask task) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.monthlyTaskDeleteConfirm(task.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (await applyToLedger(context, (ledger) => ledger.deleteMonthlyTask(task.id)) && context.mounted) {
      showMessage(context, l.monthlyTaskDeleted);
    }
  }
}

/// A task: its name, who checks it, the month it starts.
class _TaskDialog extends StatefulWidget {
  const _TaskDialog({required this.ledger, required this.task, required this.today});

  final Ledger ledger;
  final MonthlyTask? task;
  final YearMonth today;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final _name = TextEditingController(text: widget.task?.name);
  late String? _accountId = widget.task?.accountId;
  late int _month = widget.task?.since.month ?? widget.today.month;
  late int _year = widget.task?.since.year ?? widget.today.year;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accounts = [
      for (final a in widget.ledger.sortedAccounts)
        if (a.isDetailed && (!a.archived || a.id == _accountId)) a,
    ];
    final firstYear = [widget.today.year - 3, _year].reduce((a, b) => a < b ? a : b);
    return AlertDialog(
      title: Text(widget.task == null ? l.monthlyTaskNew : l.monthlyTaskEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('monthlyTaskName'),
              controller: _name,
              autofocus: widget.task == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.monthlyTaskName),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              key: const Key('monthlyTaskAccount'),
              initialValue: accounts.any((a) => a.id == _accountId) ? _accountId : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.monthlyTaskAccount,
                helperText: _accountId == null ? null : l.monthlyTaskAccountHint,
                helperMaxLines: 3,
              ),
              items: [
                DropdownMenuItem(child: Text(l.monthlyTaskByHand)),
                for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(l.monthlyTaskByImports(a.name))),
              ],
              onChanged: (id) => setState(() => _accountId = id),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    key: const Key('monthlyTaskSinceMonth'),
                    initialValue: _month,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: '${l.monthlyTaskSince} · ${l.monthlyTaskSinceMonth}'),
                    items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(fullMonthName(l, m)))],
                    onChanged: (m) => setState(() => _month = m ?? _month),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    key: const Key('monthlyTaskSinceYear'),
                    initialValue: _year,
                    decoration: InputDecoration(labelText: l.monthlyTaskSinceYear),
                    items: [
                      for (var y = firstYear; y <= widget.today.year + 1; y++)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (y) => setState(() => _year = y ?? _year),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          key: const Key('monthlyTaskSave'),
          onPressed: () =>
              Navigator.of(context)
                  .pop(MonthlyTaskDraft(name: _name.text, since: YearMonth(_year, _month), accountId: _accountId)),
          child: Text(l.save),
        ),
      ],
    );
  }
}
