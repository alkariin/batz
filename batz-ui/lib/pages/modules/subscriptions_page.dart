import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/date_field.dart';
import '../../domain/calendar_date.dart';
import '../../domain/ids.dart';
import '../../domain/modules/subscriptions.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';

String _frequency(AppLocalizations l, TrancheFrequency f) =>
    f == TrancheFrequency.monthly ? l.subscriptionPerMonthShort : l.subscriptionPerYearShort;

String _period(AppLocalizations l, Tranche t) => [
  l.subscriptionsFrom(DateField.text(t.start)),
  if (t.end case final end?) l.subscriptionsUntil(DateField.text(end)),
].join(' ');

/// Plus › « Abonnements » (step 6.6, decision H8 of phase 6): the current
/// subscriptions with their cost per month and per year and the totals,
/// then those to come and those ended.
class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final today = context.read<AppServices>().today();
    final at = ledger.subscriptionsAt(today);
    void open(String? id) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SubscriptionPage(subscriptionId: id)));
    Widget tile(Subscription s) {
      final current = s.trancheAt(today);
      final shown = current ?? (s.tranches.isEmpty ? null : s.tranches.last);
      return ListTile(
        key: ValueKey('subscription-${s.id}'),
        leading: s.hasOverlap
            ? Icon(Icons.warning_amber_outlined, color: theme.colorScheme.error)
            : const Icon(Icons.autorenew),
        title: Text(s.name),
        subtitle: Text(
          [
            if (current != null)
              l.subscriptionsCosts(formatAmount(current.monthlyCost), formatAmount(current.yearlyCost)),
            if (shown != null) _period(l, shown),
            if (s.hasOverlap) l.subscriptionsOverlap,
          ].join('\n'),
          key: ValueKey('subscriptionInfo-${s.id}'),
        ),
        isThreeLine: current != null,
        onTap: () => open(s.id),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.subscriptionsTitle)),
      floatingActionButton: FloatingActionButton(
        key: const Key('subscriptionNew'),
        tooltip: l.subscriptionNew,
        onPressed: () => open(null),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.subscriptionsTotals, style: theme.textTheme.titleMedium),
                  Row(
                    children: [
                      Expanded(child: Text(l.subscriptionsPerMonth)),
                      Text(formatAmount(at.monthlyTotal), key: const Key('subscriptionsMonthly')),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Text(l.subscriptionsPerYear)),
                      Text(formatAmount(at.yearlyTotal), key: const Key('subscriptionsYearly')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (at.all.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l.subscriptionsNone)),
          for (final (state, title) in [
            (SubscriptionState.current, l.subscriptionsCurrent),
            (SubscriptionState.upcoming, l.subscriptionsUpcoming),
            (SubscriptionState.ended, l.subscriptionsEnded),
          ])
            if (at.inState(state).isNotEmpty) ...[
              ListTile(dense: true, title: Text(title, style: theme.textTheme.titleSmall)),
              for (final s in at.inState(state)) tile(s),
            ],
        ],
      ),
    );
  }
}

/// A subscription and its tranches, or a new one with its first tranche
/// when [subscriptionId] is null.
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key, required this.subscriptionId});

  final String? subscriptionId;

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _name = TextEditingController(), _note = TextEditingController();
  late final _id = widget.subscriptionId ?? newId();
  bool _filled = false;
  TrancheDraft? _first;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<TrancheDraft?> _askTranche(Tranche? existing) => showDialog<TrancheDraft>(
    context: context,
    builder: (_) => _TrancheDialog(existing: existing, today: context.read<AppServices>().today()),
  );

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final isNew = widget.subscriptionId == null;
    if (isNew && _first == null) {
      _first = await _askTranche(null);
      if (_first == null || !mounted) return;
    }
    final saved = await applyToLedger(
      context,
      (ledger) => isNew
          ? ledger.createSubscription(_id, newId(), name: _name.text, note: _note.text, first: _first!)
          : ledger.updateSubscription(_id, name: _name.text, note: _note.text),
    );
    if (saved && mounted) {
      showMessage(context, l.subscriptionSaved);
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete(Subscription s) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.subscriptionDeleteConfirm(s.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await applyToLedger(context, (ledger) => ledger.deleteSubscription(s.id)) && mounted) {
      showMessage(context, l.subscriptionDeleted);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final subscription = ledger.modules.subscriptions[widget.subscriptionId];
    if (!_filled && subscription != null) {
      _name.text = subscription.name;
      _note.text = subscription.note;
    }
    _filled = true;
    return Scaffold(
      appBar: AppBar(
        title: Text(subscription == null ? l.subscriptionNew : l.subscriptionEdit),
        actions: [
          if (subscription != null)
            IconButton(
              key: const Key('subscriptionDelete'),
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(subscription),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('subscriptionName'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.subscriptionName),
          ),
          TextField(
            key: const Key('subscriptionNote'),
            controller: _note,
            decoration: InputDecoration(labelText: l.subscriptionNote),
          ),
          const SizedBox(height: 16),
          FilledButton(key: const Key('subscriptionSave'), onPressed: _save, child: Text(l.save)),
          if (subscription != null) ...[
            const SizedBox(height: 16),
            Text(l.subscriptionTranches, style: theme.textTheme.titleSmall),
            Text(l.subscriptionTrancheHint, style: theme.textTheme.bodySmall),
            for (final t in subscription.tranches.reversed)
              ListTile(
                key: ValueKey('tranche-${t.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.subscriptionTranche(formatAmount(t.amount), _frequency(l, t.frequency), _period(l, t))),
                trailing: IconButton(
                  key: ValueKey('trancheDelete-${t.id}'),
                  tooltip: l.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => applyToLedger(context, (ledger) => ledger.deleteTranche(t.id)),
                ),
                onTap: () async {
                  final draft = await _askTranche(t);
                  if (draft == null || !context.mounted) return;
                  await applyToLedger(context, (ledger) => ledger.updateTranche(t.id, draft));
                },
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('trancheAdd'),
                onPressed: () async {
                  final draft = await _askTranche(null);
                  if (draft == null || !context.mounted) return;
                  await applyToLedger(context, (ledger) => ledger.addTranche(subscription.id, newId(), draft));
                },
                icon: const Icon(Icons.add),
                label: Text(l.subscriptionAddTranche),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tranche: amount, frequency, start (today by default) and an optional
/// end.
class _TrancheDialog extends StatefulWidget {
  const _TrancheDialog({required this.existing, required this.today});

  final Tranche? existing;
  final CalendarDate today;

  @override
  State<_TrancheDialog> createState() => _TrancheDialogState();
}

class _TrancheDialogState extends State<_TrancheDialog> {
  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : formatAmount(widget.existing!.amount),
  );
  late final _start = TextEditingController(text: DateField.text(widget.existing?.start ?? widget.today));
  late final _end = TextEditingController(
    text: widget.existing?.end == null ? '' : DateField.text(widget.existing!.end!),
  );
  late TrancheFrequency _frequency = widget.existing?.frequency ?? TrancheFrequency.monthly;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _confirm() {
    final amount = parseAmount(_amount.text);
    final start = DateField.read(_start);
    final end = _end.text.trim().isEmpty ? null : DateField.read(_end);
    if (amount == null || start == null || (_end.text.trim().isNotEmpty && end == null)) {
      setState(() => _error = AppLocalizations.of(context).subscriptionInvalid);
      return;
    }
    Navigator.of(context).pop(TrancheDraft(amount: amount, frequency: _frequency, start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? l.subscriptionAddTranche : l.subscriptionTranches),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('trancheAmount'),
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l.subscriptionAmount, errorText: _error),
            ),
            const SizedBox(height: 8),
            SegmentedButton<TrancheFrequency>(
              key: const Key('trancheFrequency'),
              segments: [
                ButtonSegment(value: TrancheFrequency.monthly, label: Text(l.subscriptionMonthly)),
                ButtonSegment(value: TrancheFrequency.yearly, label: Text(l.subscriptionYearly)),
              ],
              selected: {_frequency},
              onSelectionChanged: (s) => setState(() => _frequency = s.single),
            ),
            DateField(controller: _start, label: l.subscriptionStart, fieldKey: const Key('trancheStart')),
            DateField(controller: _end, label: l.subscriptionEnd, fieldKey: const Key('trancheEnd')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(key: const Key('trancheSave'), onPressed: _confirm, child: Text(l.save)),
      ],
    );
  }
}
