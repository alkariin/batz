import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/date_field.dart';
import '../../domain/calendar_date.dart';
import '../../domain/journal/journal_entry.dart';
import '../../domain/ledger/account.dart';
import '../../domain/ledger/balance.dart';
import '../../domain/ledger/ledger_exception.dart';
import '../../domain/views/balances.dart';
import '../../domain/views/wealth.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../accounts/account_form_page.dart';
import '../debts/debts_page.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import '../transactions/transaction_detail_page.dart';
import '../transactions/transaction_texts.dart';

/// The screen of one account: its balance, the history of its balances
/// with the balance expected and the value variation of each, its
/// movements, and « Déclarer un solde ». The detailed account takes its
/// balance from its statements; a debts account has none of its own.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.accountId});

  final String accountId;

  String _date(CalendarDate date) => DateField.text(date);

  Future<void> _declare(BuildContext context, {DeclaredBalance? existing}) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<LedgerCubit>();
    final today = context.read<AppServices>().today();
    final result = await showDialog<_BalanceInput>(
      context: context,
      builder: (_) => _BalanceDialog(existing: existing, today: today),
    );
    if (result == null || !context.mounted) return;
    final Modification modification;
    try {
      final ledger = cubit.state.ledger;
      modification = switch (result) {
        _Delete() => ledger.deleteBalance(existing!.id),
        _Save(:final date, :final amount) when existing != null => ledger.updateBalance(
          existing.id,
          date,
          amount,
          today: today,
        ),
        _Save(:final date, :final amount) => ledger.declareBalance(accountId, date, amount, today: today),
      };
    } on LedgerException catch (e) {
      showMessage(context, ledgerErrorText(l, e));
      return;
    }
    await cubit.write(modification);
    if (!context.mounted) return;
    if (result is _Save) {
      // The value variation of the balance just declared.
      final history = cubit.state.ledger.balances.of(accountId).history;
      final step = history.where((s) => s.point.declared?.id == balanceId(accountId, result.date)).firstOrNull;
      final variation = step?.variation;
      showMessage(
        context,
        variation == null
            ? l.accountEntersWealth(formatAmount(result.amount))
            : l.accountVariationResult(formatAmount(variation, explicitPlus: true)),
      );
    } else {
      showMessage(context, l.accountBalanceDeleted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final today = context.read<AppServices>().today();
    final account = ledger.accounts[accountId];
    if (account == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.explainDeletedAccount)),
      );
    }
    final balances = ledger.balances.of(accountId);
    final canDeclare = !account.isDetailed && account.type != AccountType.debts;
    final balance = balances.balanceAt(today);
    final last = balances.lastPointDateAt(today);
    final old = ledger.wealth(today).oldBalances.any((o) => o.account.id == accountId);
    final since = balances.movementsIn(last, today);
    final history = balances.history.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            tooltip: l.accountEditAccount,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AccountFormPage(account: account))),
          ),
        ],
      ),
      floatingActionButton: canDeclare
          ? FloatingActionButton.extended(
              key: const Key('declareBalance'),
              onPressed: () => _declare(context),
              icon: const Icon(Icons.add),
              label: Text(l.accountDeclare),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.accountBalanceNow, style: theme.textTheme.labelLarge),
                  Text(
                    balance == null ? l.wealthWithoutBalance : formatAmount(balance),
                    key: const Key('accountBalance'),
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (last != null) Text(l.wealthBalanceDate(_date(last)), style: theme.textTheme.bodySmall),
                  if (old)
                    Text(
                      l.accountOldBalance,
                      key: const Key('accountOld'),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  const SizedBox(height: 8),
                  if (account.isDetailed)
                    Text(l.accountDetailedHint)
                  else if (account.type == AccountType.debts) ...[
                    Text(l.accountDebtsHint),
                    TextButton(
                      key: const Key('accountDebtsOpen'),
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DebtsPage())),
                      child: Text(l.accountDebtsOpen),
                    ),
                  ] else if (balance == null)
                    Text(l.accountNoBalance),
                ],
              ),
            ),
          ),
          if (since.isNotEmpty) ...[
            _Section(last == null ? l.accountMovementsCount(since.length) : l.accountMovementsSince),
            for (final movement in since) _MovementTile(movement),
          ],
          if (history.isNotEmpty) _Section(l.accountHistory),
          for (final step in history)
            _StepCard(
              step: step,
              onEdit: step.point.declared == null ? null : () => _declare(context, existing: step.point.declared),
            ),
          if (balances.ignored.isNotEmpty) ...[
            _Section(l.accountIgnoredBalances),
            for (final ignored in balances.ignored)
              ListTile(
                title: Text(_date(ignored.date)),
                trailing: Text(formatAmount(ignored.amount)),
                onTap: () => _declare(context, existing: ignored),
              ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// One point of the history: its balance, what was expected and the value
/// variation, then the movements since the point before.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.onEdit});

  final BalanceStep step;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final point = step.point;
    final key = point.declared?.id ?? 'statement';
    final sum = step.movements.fold(0, (total, m) => total + m.amount);
    return Card(
      key: ValueKey('balanceStep-$key'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        shape: const Border(),
        title: Row(
          children: [
            Expanded(child: Text(DateField.text(point.date))),
            Text(formatAmount(point.amount), style: theme.textTheme.titleMedium),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (point.statement != null) Text(l.accountStatementPoint),
            if (step.expected == null)
              Text(l.accountFirstBalance)
            else ...[
              Text(l.accountExpected(formatAmount(step.expected!))),
              Text(
                l.accountVariation(formatAmount(step.variation!, explicitPlus: true)),
                key: ValueKey('balanceVariation-$key'),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            Text(
              step.movements.isEmpty
                  ? l.accountMovementsCount(0)
                  : '${l.accountMovementsCount(step.movements.length)} : ${formatAmount(sum, explicitPlus: true)}',
            ),
          ],
        ),
        children: [
          if (step.expected == null && step.movements.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l.accountMovementsBefore, style: theme.textTheme.bodySmall),
            ),
          for (final movement in step.movements) _MovementTile(movement),
          if (onEdit != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: ValueKey('editBalance-$key'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.accountBalanceEdit),
              ),
            ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile(this.movement);

  final Movement movement;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.read<LedgerCubit>().state.ledger;
    final t = movement.transaction;
    return ListTile(
      dense: true,
      title: Text(titleText(l, ledger, t), overflow: TextOverflow.ellipsis),
      subtitle: Text('${DateField.text(t.date)} · ${accountsText(l, ledger, t)}'),
      trailing: Text(formatAmount(movement.amount, explicitPlus: true)),
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => TransactionDetailPage(transactionId: t.id))),
    );
  }
}

/// What the balance dialog returns.
sealed class _BalanceInput {
  const _BalanceInput();
}

class _Save extends _BalanceInput {
  const _Save(this.date, this.amount);

  final CalendarDate date;
  final int amount;
}

class _Delete extends _BalanceInput {
  const _Delete();
}

/// Declares a balance (amount, today by default) or modifies [existing].
class _BalanceDialog extends StatefulWidget {
  const _BalanceDialog({required this.existing, required this.today});

  final DeclaredBalance? existing;
  final CalendarDate today;

  @override
  State<_BalanceDialog> createState() => _BalanceDialogState();
}

class _BalanceDialogState extends State<_BalanceDialog> {
  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : formatAmount(widget.existing!.amount),
  );
  late final _date = TextEditingController(text: DateField.text(widget.existing?.date ?? widget.today));
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _date.dispose();
    super.dispose();
  }

  void _save() {
    final amount = parseAmount(_amount.text), date = DateField.read(_date);
    if (amount == null || date == null) {
      setState(() => _error = AppLocalizations.of(context).accountBalanceInvalid);
      return;
    }
    Navigator.of(context).pop(_Save(date, amount));
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.accountBalanceDeleteConfirm(DateField.text(widget.existing!.date))),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.of(context).pop(const _Delete());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? l.accountDeclare : l.accountBalanceEdit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('balanceAmount'),
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            decoration: InputDecoration(labelText: l.accountDeclareAmount, errorText: _error),
          ),
          const SizedBox(height: 8),
          DateField(controller: _date, label: l.accountDeclareDate, fieldKey: const Key('balanceDate')),
        ],
      ),
      actions: [
        if (widget.existing != null)
          TextButton(key: const Key('deleteBalance'), onPressed: _delete, child: Text(l.delete)),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(key: const Key('saveBalance'), onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
