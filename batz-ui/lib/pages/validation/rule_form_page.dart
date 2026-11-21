import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ids.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/rule.dart';
import '../../domain/period_model.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import 'validation_texts.dart';

/// Creates or modifies a mapping rule of a year: keywords, target, period
/// model. It shows, as it is typed, how many lines to validate the rule
/// would classify.
class RuleFormPage extends StatefulWidget {
  const RuleFormPage({super.key, required this.year, this.rule, this.initial});

  final int year;

  /// The rule modified; null for a new one.
  final MappingRule? rule;

  /// What a new rule starts with (from the line being classified).
  final RuleDraft? initial;

  @override
  State<RuleFormPage> createState() => _RuleFormPageState();
}

class _RuleFormPageState extends State<RuleFormPage> {
  late final TextEditingController _keywords;
  late final TextEditingController _months;
  late bool _transfer;
  String? _categoryId;
  String? _accountId;
  PeriodModel? _model;

  @override
  void initState() {
    super.initState();
    final draft = widget.rule == null ? widget.initial : RuleDraft.of(widget.rule!);
    _keywords = TextEditingController(text: draft?.keywords.join('\n') ?? '');
    _months = TextEditingController(text: draft?.periodMonths?.toString() ?? '');
    _transfer = draft?.targetAccountId != null;
    _categoryId = draft?.targetCategoryId;
    _accountId = draft?.targetAccountId;
    _model = draft?.periodModel;
  }

  @override
  void dispose() {
    _keywords.dispose();
    _months.dispose();
    super.dispose();
  }

  RuleDraft get _draft => RuleDraft(
    year: widget.year,
    keywords: [
      for (final k in _keywords.text.split('\n'))
        if (k.trim().isNotEmpty) k.trim(),
    ],
    targetCategoryId: _transfer ? null : _categoryId,
    targetAccountId: _transfer ? _accountId : null,
    periodModel: _transfer ? null : _model,
    periodMonths: int.tryParse(_months.text.trim()),
  );

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final rule = widget.rule;
    final saved = await applyToLedger(
      context,
      (ledger) => rule == null ? ledger.createRule(newId(), _draft) : ledger.updateRule(rule.id, _draft),
    );
    if (saved && mounted) {
      showMessage(context, l.ruleSaved);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete(MappingRule rule) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.ruleDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await applyToLedger(context, (ledger) => ledger.deleteRule(rule.id)) && mounted) {
      showMessage(context, l.ruleDeleted);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final tree = ledger.trees[widget.year];
    final rule = widget.rule;
    final invalid = [
      for (final k in _keywords.text.split('\n'))
        if (k.trim().isNotEmpty && !isValidKeyword(k)) k.trim(),
    ];
    final accounts = [
      for (final a in ledger.sortedAccounts)
        if (!a.isDetailed && (!a.archived || a.id == _accountId)) a,
    ];
    final categories = tree?.assignable ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(rule == null ? l.ruleNew : l.ruleEdit),
        actions: [
          if (rule != null)
            IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: () => _delete(rule)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('ruleKeywords'),
            controller: _keywords,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: l.ruleKeywords,
              helperText: l.ruleKeywordsHint,
              helperMaxLines: 3,
              errorText: invalid.isEmpty ? null : l.ruleKeywordInvalid(invalid.first),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l.classifyCategory)),
              ButtonSegment(value: true, label: Text(l.classifyTransfer)),
            ],
            selected: {_transfer},
            onSelectionChanged: (s) => setState(() => _transfer = s.first),
          ),
          const SizedBox(height: 16),
          if (!_transfer) ...[
            DropdownButtonFormField<String>(
              key: const Key('ruleCategory'),
              initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.classifyCategory),
              items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PeriodModel?>(
              key: const Key('rulePeriod'),
              initialValue: _model,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.rulePeriod),
              items: [
                for (final model in <PeriodModel?>[null, ...PeriodModel.values])
                  DropdownMenuItem(value: model, child: Text(periodModelText(l, model, null))),
              ],
              onChanged: (model) => setState(() => _model = model),
            ),
            if (_model?.takesMonths ?? false) ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('ruleMonths'),
                controller: _months,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.ruleMonths),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ] else
            DropdownButtonFormField<String>(
              key: const Key('ruleAccount'),
              initialValue: accounts.any((a) => a.id == _accountId) ? _accountId : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.classifyCounterpart),
              items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
              onChanged: (id) => setState(() => _accountId = id),
            ),
          const SizedBox(height: 16),
          Text(
            l.ruleMatches(ledger.linesClassifiedBy(_draft, replacing: rule?.id)),
            key: const Key('ruleMatches'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(key: const Key('ruleSave'), onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}
