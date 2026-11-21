import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/calendar_date.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import 'rule_form_page.dart';
import 'validation_texts.dart';

/// Plus › Règles de classement: the mapping rules of a year, those whose
/// target is unusable marked.
class RulesPage extends StatefulWidget {
  const RulesPage({super.key, this.initialYear});

  final int? initialYear;

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final years = ledger.yearsWithTree;
    final year =
        _year ??
        widget.initialYear ??
        (years.contains(CalendarDate.today().year) || years.isEmpty ? CalendarDate.today().year : years.last);
    final rules = ledger.rulesOf(year);
    final unusable = {for (final r in ledger.unusableRules) r.id};
    final hasTree = ledger.trees.containsKey(year);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.rulesTitle(year)),
        actions: [
          if (years.isNotEmpty)
            DropdownButton<int>(
              key: const Key('rulesYear'),
              value: years.contains(year) ? year : null,
              items: [for (final y in years.reversed) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: (y) => setState(() => _year = y),
            ),
        ],
      ),
      floatingActionButton: hasTree
          ? FloatingActionButton(
              tooltip: l.ruleNew,
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => RuleFormPage(year: year))),
              child: const Icon(Icons.add),
            )
          : null,
      body: !hasTree
          ? Center(child: Text(l.rulesNoTree))
          : rules.isEmpty
          ? Center(child: Text(l.rulesEmpty))
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final rule in rules)
                  ListTile(
                    key: ValueKey('rule-${rule.id}'),
                    leading: unusable.contains(rule.id)
                        ? Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error)
                        : const Icon(Icons.rule),
                    title: Text(keywordsText(rule)),
                    subtitle: Text(
                      [
                        ruleTargetText(l, ledger, rule),
                        if (!rule.isTransfer) periodModelText(l, rule.periodModel, rule.periodMonths),
                        if (unusable.contains(rule.id)) l.ruleUnusable,
                      ].join(' · '),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                        builder: (_) => RuleFormPage(year: year, rule: rule),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
