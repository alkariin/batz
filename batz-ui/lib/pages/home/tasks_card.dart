import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ledger/issues.dart';
import '../../l10n/app_localizations.dart';
import '../accounts/accounts_page.dart';
import '../categories/categories_page.dart';
import '../ledger_cubit.dart';

/// The tasks of the home screen: for now, the inconsistencies a merge can
/// leave (decision H4 of phase 2), each leading to the screen that corrects
/// it.
class TasksCard extends StatelessWidget {
  const TasksCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<LedgerCubit, LedgerState>(
      builder: (context, state) {
        final issues = state.ledger.issues;
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(title: Text(l.tasksTitle, style: Theme.of(context).textTheme.titleMedium)),
              if (issues.isEmpty)
                ListTile(dense: true, title: Text(l.tasksNone))
              else
                for (final issue in issues) _task(context, l, issue),
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
    return ListTile(
      leading: Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error),
      title: Text(title),
      subtitle: Text(hint),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
    );
  }
}
