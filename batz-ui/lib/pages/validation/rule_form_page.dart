import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ids.dart';
import '../../domain/ledger/rule.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import 'rules_help.dart';

/// Creates or modifies a mapping rule of a year: its lines, one of which
/// must match, and its target. It shows, as it is typed, how many lines to
/// validate the rule would classify.
///
/// A rule opened from its category keeps that category; a transfer rule
/// keeps its kind and chooses its account. From the validation, where the
/// classification is still being chosen, [chooseTarget] offers both.
class RuleFormPage extends StatefulWidget {
  const RuleFormPage({super.key, required this.year, this.rule, this.initial, this.chooseTarget = false});

  final int year;

  /// The rule modified; null for a new one.
  final MappingRule? rule;

  /// What a new rule starts with: its category, or the line being
  /// classified.
  final RuleDraft? initial;

  /// Whether the target can be any category or any account.
  final bool chooseTarget;

  @override
  State<RuleFormPage> createState() => _RuleFormPageState();
}

class _RuleFormPageState extends State<RuleFormPage> {
  late final TextEditingController _lines;
  late bool _transfer;
  String? _categoryId;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    final draft = widget.rule == null ? widget.initial : RuleDraft.of(widget.rule!);
    _lines = TextEditingController(text: draft?.lines.join('\n') ?? '');
    _transfer = draft?.targetAccountId != null || (!widget.chooseTarget && draft?.targetCategoryId == null);
    _categoryId = draft?.targetCategoryId;
    _accountId = draft?.targetAccountId;
  }

  @override
  void dispose() {
    _lines.dispose();
    super.dispose();
  }

  RuleDraft get _draft => RuleDraft(
    year: widget.year,
    lines: ruleLinesOf(_lines.text),
    targetCategoryId: _transfer ? null : _categoryId,
    targetAccountId: _transfer ? _accountId : null,
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
      for (final line in ruleLinesOf(_lines.text))
        if (!isValidRuleLine(line)) line,
    ];
    final accounts = [
      for (final a in ledger.sortedAccounts)
        if (!a.archived || a.id == _accountId) a,
    ];
    final categories = tree?.assignable ?? const [];
    final accountPicker = DropdownButtonFormField<String>(
      key: const Key('ruleAccount'),
      initialValue: accounts.any((a) => a.id == _accountId) ? _accountId : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: l.classifyCounterpart),
      items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
      onChanged: (id) => setState(() => _accountId = id),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(rule == null ? l.ruleNew : l.ruleEdit),
        actions: [
          const RulesHelpButton(),
          if (rule != null)
            IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: () => _delete(rule)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.chooseTarget && !_transfer) ...[
            Text(
              l.ruleFor(ledger.categories[_categoryId]?.name ?? '?'),
              key: const Key('ruleCategoryName'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            key: const Key('ruleKeywords'),
            controller: _lines,
            minLines: 3,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: l.ruleKeywords,
              helperText: l.ruleKeywordsHint,
              helperMaxLines: 3,
              errorText: invalid.isEmpty ? null : l.ruleKeywordInvalid(invalid.first),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (widget.chooseTarget) ...[
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l.classifyCategory)),
                ButtonSegment(value: true, label: Text(l.classifyTransfer)),
              ],
              selected: {_transfer},
              onSelectionChanged: (s) => setState(() => _transfer = s.first),
            ),
            const SizedBox(height: 16),
            if (!_transfer)
              DropdownButtonFormField<String>(
                key: const Key('ruleCategory'),
                initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.classifyCategory),
                items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (id) => setState(() => _categoryId = id),
              )
            else
              accountPicker,
            const SizedBox(height: 16),
          ] else if (_transfer) ...[
            accountPicker,
            const SizedBox(height: 16),
          ],
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
