import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/date_field.dart';
import '../../domain/calendar_date.dart';
import '../../domain/ids.dart';
import '../../domain/journal/journal_entry.dart';
import '../../domain/ledger/debt.dart';
import '../../domain/ledger/ledger_exception.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import 'debt_form_page.dart';

/// The debts table, from « Fortune »: the debts not repaid first, each
/// with its person, its direction, its total and its dates; the totals «
/// on me doit », « je dois » and net of the debts that count today, which
/// is the line « Dettes » of the wealth. A debt is checked as repaid,
/// unchecked, split, deleted.
class DebtsPage extends StatelessWidget {
  const DebtsPage({super.key});

  static String direction(AppLocalizations l, DebtDirection direction) => switch (direction) {
    DebtDirection.owedToMe => l.debtOwedToMe,
    DebtDirection.iOwe => l.debtIOwe,
  };

  Future<void> _write(BuildContext context, Modification Function() build, {String? done}) async {
    final l = AppLocalizations.of(context);
    final Modification modification;
    try {
      modification = build();
    } on LedgerException catch (e) {
      showMessage(context, ledgerErrorText(l, e));
      return;
    }
    await context.read<LedgerCubit>().write(modification);
    if (done != null && context.mounted) showMessage(context, done);
  }

  /// Checking proposes today as the date of receipt.
  Future<void> _check(BuildContext context, Debt debt) async {
    final today = context.read<AppServices>().today();
    final received = await showDialog<_Received>(
      context: context,
      builder: (_) => _CheckDialog(today: today),
    );
    if (received == null || !context.mounted) return;
    final ledger = context.read<LedgerCubit>().state.ledger;
    await _write(context, () => ledger.checkDebt(debt.id, receivedDate: received.date, today: today));
  }

  Future<void> _split(BuildContext context, Debt debt) async {
    final l = AppLocalizations.of(context);
    final first = await showDialog<int>(
      context: context,
      builder: (_) => _SplitDialog(total: debt.total),
    );
    if (first == null || !context.mounted) return;
    final ledger = context.read<LedgerCubit>().state.ledger;
    await _write(
      context,
      () => ledger.splitDebt(debt.id, newId(), first),
      done: l.debtSplitDone(formatAmount(first), formatAmount(debt.total - first)),
    );
  }

  Future<void> _delete(BuildContext context, Debt debt) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.debtDeleteConfirm(debt.person)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ledger = context.read<LedgerCubit>().state.ledger;
    await _write(context, () => ledger.deleteDebt(debt.id), done: l.debtDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final today = context.read<AppServices>().today();
    final debts = ledger.sortedDebts;
    final totals = ledger.debtTotalsAt(today);
    final open = debts.where((d) => !d.repaid).toList(), repaid = debts.where((d) => d.repaid).toList();

    Widget tile(Debt debt) {
      final dates = [
        l.debtSince(DateField.text(debt.start)),
        if (debt.receivedDate case final received?) l.debtReceivedOn(DateField.text(received)),
      ];
      return ListTile(
        key: ValueKey('debt-${debt.id}'),
        leading: Checkbox(
          key: ValueKey('debtCheck-${debt.id}'),
          value: debt.repaid,
          onChanged: (value) =>
              value == true ? _check(context, debt) : _write(context, () => ledger.uncheckDebt(debt.id)),
        ),
        title: Text(debt.description.isEmpty ? debt.person : '${debt.person} · ${debt.description}'),
        subtitle: Text([direction(l, debt.direction), ...dates].join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatAmount(debt.signedTotal, explicitPlus: true),
              key: ValueKey('debtTotal-${debt.id}'),
              style: theme.textTheme.titleSmall,
            ),
            PopupMenuButton<String>(
              key: ValueKey('debtMenu-${debt.id}'),
              onSelected: (action) => action == 'split' ? _split(context, debt) : _delete(context, debt),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'split', child: Text(l.debtSplit)),
                PopupMenuItem(value: 'delete', child: Text(l.delete)),
              ],
            ),
          ],
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DebtFormPage(debt: debt))),
      );
    }

    Widget total(String key, String label, int cents, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: strong ? theme.textTheme.titleSmall : null)),
          Text(
            formatAmount(cents),
            key: ValueKey(key),
            style: strong ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.debtsTitle)),
      floatingActionButton: FloatingActionButton(
        key: const Key('newDebt'),
        tooltip: l.debtNew,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DebtFormPage())),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  total('debtsOwedToMe', l.debtsOwedToMe, totals.owedToMe),
                  total('debtsIOwe', l.debtsIOwe, totals.iOwe),
                  const Divider(),
                  total('debtsNet', l.debtsNet, totals.net, strong: true),
                ],
              ),
            ),
          ),
          if (debts.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l.debtsEmpty)),
          if (open.isNotEmpty) ...[
            ListTile(dense: true, title: Text(l.debtsOpen, style: theme.textTheme.titleSmall)),
            for (final debt in open) tile(debt),
          ],
          if (repaid.isNotEmpty) ...[
            ListTile(dense: true, title: Text(l.debtsRepaid, style: theme.textTheme.titleSmall)),
            for (final debt in repaid) tile(debt),
          ],
        ],
      ),
    );
  }
}

class _Received {
  const _Received(this.date);

  final CalendarDate? date;
}

/// Checks a debt as repaid: the date of receipt, today by default, or none.
class _CheckDialog extends StatefulWidget {
  const _CheckDialog({required this.today});

  final CalendarDate today;

  @override
  State<_CheckDialog> createState() => _CheckDialogState();
}

class _CheckDialogState extends State<_CheckDialog> {
  late final _date = TextEditingController(text: DateField.text(widget.today));
  String? _error;

  @override
  void dispose() {
    _date.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _date.text.trim();
    final date = DateField.read(_date);
    if (text.isNotEmpty && date == null) {
      setState(() => _error = AppLocalizations.of(context).debtInvalidDate);
      return;
    }
    Navigator.of(context).pop(_Received(date));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.debtCheckTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.debtCheckHint),
          const SizedBox(height: 8),
          DateField(controller: _date, label: l.debtReceivedDate, fieldKey: const Key('debtCheckDate')),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(key: const Key('debtCheckConfirm'), onPressed: _confirm, child: Text(l.confirm)),
      ],
    );
  }
}

/// Asks for the first part of a split, taken from [total].
class _SplitDialog extends StatefulWidget {
  const _SplitDialog({required this.total});

  final int total;

  @override
  State<_SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends State<_SplitDialog> {
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _confirm() {
    final cents = parseAmount(_amount.text);
    if (cents == null || cents <= 0 || cents >= widget.total) {
      setState(() => _error = AppLocalizations.of(context).errorDebtSplitOutOfTotal);
      return;
    }
    Navigator.of(context).pop(cents);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.debtSplitTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.debtSplitHint(formatAmount(widget.total))),
          const SizedBox(height: 8),
          TextField(
            key: const Key('debtSplitAmount'),
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.debtSplitFirst, errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(key: const Key('debtSplitConfirm'), onPressed: _confirm, child: Text(l.debtSplit)),
      ],
    );
  }
}
