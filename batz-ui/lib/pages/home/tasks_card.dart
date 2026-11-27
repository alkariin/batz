import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ledger/issues.dart';
import '../../domain/ledger/redistribution.dart';
import '../../domain/ledger/refund.dart';
import '../../domain/views/share_operations.dart';
import '../../domain/views/wealth.dart';
import '../../components/date_field.dart';
import '../../services.dart';
import '../../l10n/app_localizations.dart';
import '../categories/categories_page.dart';
import '../ledger_cubit.dart';
import '../lock/lock_cubit.dart';
import '../redistribution/redistribution_page.dart';
import '../refunds/broken_refunds_page.dart';
import '../transactions/unpaired_transfers_page.dart';
import '../shares/shares_page.dart';
import '../validation/validation_page.dart';
import '../wealth/account_page.dart';

/// The tasks of the home screen: the lines to validate, the lines whose
/// rules compete, the rules that propose nothing any more, the shares to
/// classify, the redistribution rules that do not apply, the refunds that
/// lost their expense, the transfers between imported accounts without
/// their other side after [unpairedTaskDays] days, the balances declared
/// more than six months ago, and the inconsistencies a merge can leave,
/// each leading to the screen that deals with it.
/// The days a transfer between imported accounts waits for its other side
/// before it is a task.
const unpairedTaskDays = 10;

class TasksCard extends StatelessWidget {
  const TasksCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = context.read<AppServices>().today();
    // The device has no screen lock: the app opened without
    // asking, and says so while it lasts.
    final noScreenLock = context.select<LockCubit, bool>((lock) => lock.state.noScreenLock);
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
        final inapplicable = <int, int>{};
        for (final i in ledger.inapplicableRedistributions) {
          inapplicable[i.rule.year] = (inapplicable[i.rule.year] ?? 0) + 1;
        }
        final shares = ledger.pendingShareCount;
        final broken = ledger.brokenRefunds.length;
        // The other statement takes some days to be imported.
        final unpairedSince = today.addDays(-unpairedTaskDays);
        final unpaired = ledger.unpairedTransfers.where((t) => !t.date.isAfter(unpairedSince)).length;
        final old = ledger.wealth(today).oldBalances;
        final tasks = [
          if (noScreenLock)
            ListTile(
              key: const Key('taskNoScreenLock'),
              leading: Icon(Icons.no_encryption_outlined, color: Theme.of(context).colorScheme.error),
              title: Text(l.taskNoScreenLock),
              subtitle: Text(l.taskNoScreenLockHint),
            ),
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
              CategoriesPage(initialYear: year),
              warning: true,
            ),
          if (shares > 0)
            _tile(
              context,
              Icons.move_down,
              l.taskShares(shares),
              l.taskSharesHint,
              const SharesPage(),
              key: const Key('taskShares'),
            ),
          for (final MapEntry(key: year, value: count) in inapplicable.entries)
            _tile(
              context,
              Icons.warning_amber_outlined,
              l.taskInapplicableRedistributions(count, '$year'),
              l.taskInapplicableRedistributionsHint,
              RedistributionPage(initialYear: year),
              warning: true,
              key: ValueKey('taskInapplicable-$year'),
            ),
          if (broken > 0)
            _tile(
              context,
              Icons.link_off,
              l.taskBrokenRefunds(broken),
              l.taskBrokenRefundsHint,
              const BrokenRefundsPage(),
              warning: true,
              key: const Key('taskBrokenRefunds'),
            ),
          if (unpaired > 0)
            _tile(
              context,
              Icons.link_off,
              l.taskUnpairedTransfers(unpaired),
              l.taskUnpairedTransfersHint,
              const UnpairedTransfersPage(),
              warning: true,
              key: const Key('taskUnpairedTransfers'),
            ),
          for (final balance in old)
            _tile(
              context,
              Icons.update,
              l.taskOldBalance(balance.account.name),
              l.taskOldBalanceHint(DateField.text(balance.lastDeclared.date)),
              AccountPage(accountId: balance.account.id),
              key: ValueKey('taskOldBalance-${balance.account.id}'),
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
