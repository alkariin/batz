import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/proposal.dart';
import '../../domain/ledger/transaction.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import 'classify_page.dart';
import 'validation_texts.dart';

/// The validation of imported lines, in two parts: the lines to complete,
/// one by one, with their whole bank text; the proposed lines, with their
/// proposal and the rule that gives it, corrected if need be and confirmed
/// in bulk. Everything is local: it works offline and can be left at any
/// time.
class ValidationPage extends StatelessWidget {
  const ValidationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final lines = ledger.linesToValidate;
    final toComplete = [
      for (final t in lines)
        if (ledger.validationStateOf(t) == ValidationState.toComplete) t,
    ];
    final proposed = [
      for (final t in lines)
        if (ledger.validationStateOf(t) == ValidationState.proposed) t,
    ];
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.validationTitle),
          bottom: TabBar(
            tabs: [
              Tab(key: const Key('tabToComplete'), text: l.validationToCompleteTab(toComplete.length)),
              Tab(key: const Key('tabProposed'), text: l.validationProposedTab(proposed.length)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            toComplete.isEmpty
                ? Center(child: Text(l.validationNothingToComplete))
                : ListView.builder(
                    key: const Key('toCompleteList'),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: toComplete.length,
                    itemBuilder: (context, i) => _toComplete(context, ledger, toComplete[i]),
                  ),
            Column(
              children: [
                Expanded(
                  child: proposed.isEmpty
                      ? Center(child: Text(l.validationNothingProposed))
                      : ListView.builder(
                          itemCount: proposed.length,
                          itemBuilder: (context, i) => _proposed(context, ledger, proposed[i]),
                        ),
                ),
                if (proposed.isNotEmpty)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('confirmProposals'),
                          icon: const Icon(Icons.done_all),
                          label: Text(l.validationConfirm(proposed.length)),
                          onPressed: () => _confirm(context, [for (final t in proposed) t.id]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toComplete(BuildContext context, Ledger ledger, LedgerTransaction t) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final outcome = ledger.proposals[t.id];
    return Card(
      key: ValueKey('toComplete-${t.id}'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: InkWell(
        onTap: () => _open(context, t),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(formatDate(t.date.toDateTime()), style: theme.textTheme.labelLarge)),
                  Text(formatAmount(t.amount), style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 4),
              Text(t.rawText ?? t.description),
              if (outcome case Conflict(:final rules))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.validationConflict(
                      rules.map((r) => '« ${keywordsText(l, r)} » → ${ruleTargetText(l, ledger, r)}').join(' ; '),
                    ),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (outcome case UnusableRule(:final rule))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.validationUnusable(keywordsText(l, rule)),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _proposed(BuildContext context, Ledger ledger, LedgerTransaction t) {
    final l = AppLocalizations.of(context);
    final p = ledger.proposals[t.id]! as Proposed;
    return ListTile(
      key: ValueKey('proposed-${t.id}'),
      title: Text(t.description.isEmpty ? (t.rawText ?? '') : t.description),
      subtitle: Text(
        '${formatDate(t.date.toDateTime())} · ${classificationText(l, ledger, p.classification)}\n'
        '${l.validationRule(keywordsText(l, p.rule))}',
      ),
      isThreeLine: true,
      trailing: Text(formatAmount(t.amount), style: Theme.of(context).textTheme.titleSmall),
      onTap: () => _open(context, t),
    );
  }

  void _open(BuildContext context, LedgerTransaction t) {
    Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => ClassifyPage(transactionId: t.id)));
  }

  Future<void> _confirm(BuildContext context, List<String> ids) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<LedgerCubit>();
    final modifications = cubit.state.ledger.confirmProposals(ids);
    var count = 0;
    for (final m in modifications) {
      await cubit.write(m);
      count += m.changes.where((c) => c.field == TransactionFields.status).length;
    }
    if (context.mounted) showMessage(context, l.validationConfirmed(count));
  }
}
