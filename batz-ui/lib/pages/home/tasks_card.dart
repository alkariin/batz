import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ledger/issues.dart';
import '../../l10n/app_localizations.dart';
import '../accounts/accounts_page.dart';
import '../categories/categories_page.dart';
import '../ledger_cubit.dart';
import '../validation/rules_page.dart';
import '../validation/validation_page.dart';

/// The tasks of the home screen (specification, 4.6): the lines to
/// validate, the lines whose rules compete, the rules that propose nothing
/// any more, and the inconsistencies a merge can leave (decision H4 of
/// phase 2), each leading to the screen that deals with it.
class TasksCard extends StatelessWidget {
  const TasksCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<LedgerCubit, LedgerState>(
      builder: (context, state) {
        final ledger = state.ledger;
        final issues = ledger.issues;
        final toValidate = ledger.linesToValidate.length;
        final conflicts = ledger.conflictingLines;
        final unusable = <int, int>{};
        for (final rule in ledger.unusableRules) {
          unusable[rule.year] = (unusable[rule.year] ?? 0) + 1;
        }
        final tasks = [
          if (toValidate > 0)
            _tile(
              context,
              Icons.fact_check_outlined,
              l.taskLinesToValidate(toValidate),
              l.taskLinesToValidateHint,
              const ValidationPage(),
              key: const Key('taskLinesToValidate'),
            ),
          if (conflicts > 0)
            _tile(
              context,
              Icons.call_split,
              l.taskConflicts(conflicts),
              l.taskConflictsHint,
              const ValidationPage(),
              key: const Key('taskConflicts'),
            ),
          for (final MapEntry(key: year, value: count) in unusable.entries)
            _tile(
              context,
              Icons.warning_amber_outlined,
              l.taskUnusableRules(count, year),
              l.taskUnusableRulesHint,
              RulesPage(initialYear: year),
              warning: true,
            ),
          for (final issue in issues) _task(context, l, issue),
        ];
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(title: Text(l.tasksTitle, style: Theme.of(context).textTheme.titleMedium)),
              if (tasks.isEmpty) ListTile(dense: true, title: Text(l.tasksNone)) else ...tasks,
            ],
          ),
        );
      },
    );
  }

  Widget _task(BuildContext context, AppLocalizations l, LedgerIssue issue) {
    final (title, hint, page) = switch (issue) {
      DuplicateCategoryName(:final year, :final categories, :final name) => (
        l.taskDuplicateName(categories.length, name, year),
        l.taskDuplicateNameHint,
        CategoriesPage(initialYear: year) as Widget,
      ),
      SeveralDetailedAccounts(:final accounts) => (
        l.taskDetailedAccounts(accounts.length),
        l.taskDetailedAccountsHint,
        const AccountsPage(),
      ),
      DetachedCategories(:final year, :final heads) => (
        l.taskDetached(heads.length, year),
        l.taskDetachedHint,
        CategoriesPage(initialYear: year),
      ),
    };
    return _tile(context, Icons.warning_amber_outlined, title, hint, page, warning: true);
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String hint,
    Widget page, {
    bool warning = false,
    Key? key,
  }) => ListTile(
    key: key,
    leading: Icon(icon, color: warning ? Theme.of(context).colorScheme.error : null),
    title: Text(title),
    subtitle: Text(hint),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
  );
}
