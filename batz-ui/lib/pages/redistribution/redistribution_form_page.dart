import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ids.dart';
import '../../domain/ledger/redistribution.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';

/// Creates or modifies a redistribution rule of a year: source, target, and
/// a percentage or a fixed amount per payment. The domain refuses a rule it
/// cannot apply and says why.
class RedistributionFormPage extends StatefulWidget {
  const RedistributionFormPage({super.key, required this.year, this.rule});

  final int year;

  /// The rule modified; null for a new one.
  final RedistributionRule? rule;

  @override
  State<RedistributionFormPage> createState() => _RedistributionFormPageState();
}

class _RedistributionFormPageState extends State<RedistributionFormPage> {
  late String? _source = widget.rule?.sourceId;
  late String? _target = widget.rule?.targetId;
  late bool _fixed = widget.rule?.isFixed ?? false;
  late final _percent = TextEditingController(
    text: widget.rule?.basisPoints == null ? '' : formatPercent(widget.rule!.basisPoints!).replaceFirst(' %', ''),
  );
  late final _amount = TextEditingController(
    text: widget.rule?.amount == null ? '' : formatAmount(widget.rule!.amount!),
  );

  @override
  void dispose() {
    _percent.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final basisPoints = _fixed ? null : parsePercent(_percent.text);
    final amount = _fixed ? parseAmount(_amount.text) : null;
    final String? problem = _source == null
        ? l.redistributionChooseSource
        : _target == null
        ? l.redistributionChooseTarget
        : !_fixed && basisPoints == null
        ? l.errorRedistributionPercentInvalid
        : _fixed && (amount == null || amount <= 0)
        ? l.errorRedistributionAmountInvalid
        : null;
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    final draft = RedistributionDraft(
      year: widget.year,
      sourceId: _source!,
      targetId: _target!,
      basisPoints: basisPoints,
      amount: amount,
    );
    final rule = widget.rule;
    final saved = await applyToLedger(
      context,
      (ledger) =>
          rule == null ? ledger.createRedistribution(newId(), draft) : ledger.updateRedistribution(rule.id, draft),
    );
    if (saved && mounted) {
      showMessage(context, l.redistributionSaved);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete(RedistributionRule rule) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.redistributionDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await applyToLedger(context, (ledger) => ledger.deleteRedistribution(rule.id)) && mounted) {
      showMessage(context, l.redistributionDeleted);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final tree = ledger.trees[widget.year];
    final categories = tree?.assignable ?? const [];
    DropdownMenuItem<String> item(String id) => DropdownMenuItem(
      value: id,
      child: Text('${tree!.byId[id]!.name} · ${natureText(l, tree.natureOf(id))}', overflow: TextOverflow.ellipsis),
    );
    final rule = widget.rule;
    return Scaffold(
      appBar: AppBar(
        title: Text(rule == null ? l.redistributionNew : l.redistributionEdit),
        actions: [
          if (rule != null)
            IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: () => _delete(rule)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.redistributionExplain, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('redistributionSource'),
            initialValue: categories.any((c) => c.id == _source) ? _source : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.redistributionSource),
            items: [for (final c in categories) item(c.id)],
            onChanged: (id) => setState(() => _source = id),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('redistributionTarget'),
            initialValue: categories.any((c) => c.id == _target) ? _target : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.redistributionTarget),
            items: [for (final c in categories) item(c.id)],
            onChanged: (id) => setState(() => _target = id),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            key: const Key('redistributionKind'),
            segments: [
              ButtonSegment(value: false, label: Text(l.redistributionPercent)),
              ButtonSegment(value: true, label: Text(l.redistributionFixed)),
            ],
            selected: {_fixed},
            onSelectionChanged: (s) => setState(() => _fixed = s.single),
          ),
          const SizedBox(height: 16),
          if (_fixed)
            TextField(
              key: const Key('redistributionAmount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.redistributionAmount,
                suffixText: 'CHF',
                helperText: l.redistributionAmountHint,
                helperMaxLines: 3,
              ),
            )
          else
            TextField(
              key: const Key('redistributionPercent'),
              controller: _percent,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.redistributionPercent,
                suffixText: '%',
                helperText: l.redistributionPercentHint,
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(key: const Key('redistributionSave'), onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}
