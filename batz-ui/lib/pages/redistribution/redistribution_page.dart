import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/calendar_date.dart';
import '../../domain/ledger/redistribution.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import 'redistribution_form_page.dart';

/// The reason a redistribution rule does not apply, for the user.
String redistributionProblemText(AppLocalizations l, RedistributionProblem problem) => switch (problem) {
  RedistributionProblem.sourceMissing => l.redistributionProblemSourceMissing,
  RedistributionProblem.targetMissing => l.redistributionProblemTargetMissing,
  RedistributionProblem.sourceNotLeaf => l.redistributionProblemSourceNotLeaf,
  RedistributionProblem.targetNotLeaf => l.redistributionProblemTargetNotLeaf,
  RedistributionProblem.sameCategory => l.redistributionProblemSameCategory,
  RedistributionProblem.natureMismatch => l.redistributionProblemNatureMismatch,
  RedistributionProblem.percentInvalid => l.redistributionProblemPercentInvalid,
  RedistributionProblem.amountInvalid => l.redistributionProblemAmountInvalid,
  RedistributionProblem.percentOrAmount => l.redistributionProblemPercentOrAmount,
  RedistributionProblem.overHundred => l.redistributionProblemOverHundred,
  RedistributionProblem.chain => l.redistributionProblemChain,
};

/// What [rule] moves: its percentage, or its fixed amount per payment.
String redistributionValueText(AppLocalizations l, RedistributionRule rule) => switch (rule) {
  RedistributionRule(:final amount?, basisPoints: null) => l.redistributionPerPayment(formatAmount(amount)),
  RedistributionRule(:final basisPoints?, amount: null) => formatPercent(basisPoints),
  _ => '?',
};

/// Plus › Redistribution: the redistribution rules of a year, those that do
/// not apply marked with their reason.
class RedistributionPage extends StatefulWidget {
  const RedistributionPage({super.key, this.initialYear});

  final int? initialYear;

  @override
  State<RedistributionPage> createState() => _RedistributionPageState();
}

class _RedistributionPageState extends State<RedistributionPage> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final years = ledger.yearsWithTree;
    final today = CalendarDate.today().year;
    final year = _year ?? widget.initialYear ?? (years.contains(today) || years.isEmpty ? today : years.last);
    final tree = ledger.trees[year];
    final rules = ledger.redistributionsOf(year);
    final problems = tree == null ? const <String, RedistributionProblem?>{} : redistributionProblems(rules, tree);
    String name(String id) => ledger.categories[id]?.name ?? '?';
    return Scaffold(
      appBar: AppBar(
        title: Text(l.redistributionTitle('$year')),
        actions: [
          if (years.isNotEmpty)
            DropdownButton<int>(
              key: const Key('redistributionYear'),
              value: years.contains(year) ? year : null,
              items: [for (final y in years.reversed) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: (y) => setState(() => _year = y),
            ),
        ],
      ),
      floatingActionButton: tree == null
          ? null
          : FloatingActionButton(
              key: const Key('redistributionNew'),
              tooltip: l.redistributionNew,
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<bool>(builder: (_) => RedistributionFormPage(year: year))),
              child: const Icon(Icons.add),
            ),
      body: tree == null
          ? Center(child: Text(l.redistributionNoTree))
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                ListTile(subtitle: Text(l.redistributionExplain)),
                if (rules.isEmpty) ListTile(title: Text(l.redistributionEmpty)),
                for (final rule in rules)
                  ListTile(
                    key: ValueKey('redistribution-${rule.id}'),
                    leading: problems[rule.id] == null
                        ? const Icon(Icons.call_split)
                        : Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error),
                    title: Text(l.redistributionRule(name(rule.sourceId), name(rule.targetId))),
                    subtitle: Text(
                      [
                        redistributionValueText(l, rule),
                        if (problems[rule.id] case final problem?) redistributionProblemText(l, problem),
                      ].join(' · '),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                        builder: (_) => RedistributionFormPage(year: year, rule: rule),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
