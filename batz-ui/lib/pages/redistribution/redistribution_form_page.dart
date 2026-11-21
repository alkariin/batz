import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ids.dart';
import '../../domain/ledger/redistribution.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';

/// Creates or modifies a redistribution rule of a year: source, target and
/// percentage. The domain refuses a rule it cannot apply and says why.
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
  late final _percent = TextEditingController(
    text: widget.rule == null ? '' : formatPercent(widget.rule!.basisPoints).replaceFirst(' %', ''),
  );

  @override
  void dispose() {
    _percent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final basisPoints = parsePercent(_percent.text);
    final String? problem = _source == null
        ? l.redistributionChooseSource
        : _target == null
        ? l.redistributionChooseTarget
        : basisPoints == null
        ? l.errorRedistributionPercentInvalid
        : null;
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    final draft = RedistributionDraft(
      year: widget.year,
      sourceId: _source!,
      targetId: _target!,
      basisPoints: basisPoints!,
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
