import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ledger/account.dart';
import '../../domain/ledger/statement.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import '../sync/sync_cubit.dart';
import '../validation/validation_page.dart';
import 'import_cubit.dart';
import 'statements_page.dart';

/// Transactions › Importer un relevé: synchronisation, choice of the
/// account and of the file (a PDF statement, a CSV export), the server's
/// reading and checks, the balance typed for an export, the app's checks,
/// then the result or the reason of the refusal.
class ImportPage extends StatelessWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    return BlocProvider(
      create: (context) => ImportCubit(
        sync: context.read<SyncCubit>(),
        ledger: context.read<LedgerCubit>(),
        server: services.server,
        transport: services.importTransport,
        today: services.today,
      )..start(),
      child: const _ImportView(),
    );
  }
}

class _ImportView extends StatefulWidget {
  const _ImportView();

  @override
  State<_ImportView> createState() => _ImportViewState();
}

class _ImportViewState extends State<_ImportView> {
  String? _accountId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.importTitle)),
      body: BlocConsumer<ImportCubit, ImportState>(
        listenWhen: (previous, current) =>
            (current.step == ImportStep.confirmFirst || current.step == ImportStep.askBalance) &&
            previous.step != current.step,
        listener: (context, state) =>
            state.step == ImportStep.confirmFirst ? _confirmFirst(context, state) : _askBalance(context, state),
        builder: (context, state) => switch (state.step) {
          ImportStep.syncing => _progress(l.importSyncing),
          ImportStep.notReady => _notReady(context, state),
          _ => _form(context, state),
        },
      ),
    );
  }

  Widget _progress(String text) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(text)],
    ),
  );

  Widget _notReady(BuildContext context, ImportState state) {
    final l = AppLocalizations.of(context);
    final reason = switch (state.syncStatus) {
      SyncStatus.notPaired => l.syncNotPaired,
      SyncStatus.offline => l.syncOffline,
      SyncStatus.revoked => l.syncRevoked,
      SyncStatus.serverChanged => l.syncServerChanged,
      SyncStatus.incompatible => l.syncIncompatible,
      SyncStatus.decisionNeeded => l.syncDecision,
      _ => l.syncError,
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: Icon(Icons.cloud_off_outlined, color: Theme.of(context).colorScheme.error),
          title: Text(l.importNotReady(reason), key: const Key('importNotReady')),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(onPressed: () => context.read<ImportCubit>().start(), child: Text(l.importRetry)),
        ),
      ],
    );
  }

  Widget _form(BuildContext context, ImportState state) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final accounts = ledger.sortedAccounts.where((a) => a.isDetailed && !a.archived).toList();
    if (accounts.isEmpty) {
      return Padding(padding: const EdgeInsets.all(16), child: Text(l.importNoDetailedAccount));
    }
    final account = accounts.firstWhere((a) => a.id == _accountId, orElse: () => accounts.first);
    final busy = const {ImportStep.sending, ImportStep.confirmFirst, ImportStep.askBalance}.contains(state.step);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          key: const Key('importAccount'),
          initialValue: account.id,
          decoration: InputDecoration(labelText: l.importAccount),
          items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
          onChanged: busy ? null : (id) => setState(() => _accountId = id),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('importChoose'),
          icon: const Icon(Icons.upload_file),
          label: Text(l.importChoose),
          onPressed: busy ? null : () => _choose(context, account),
        ),
        const SizedBox(height: 16),
        if (state.step == ImportStep.sending) _progress(l.importSending),
        if (state.step == ImportStep.refused && state.refusal != null) _refusal(context, state.refusal!),
        if (state.step == ImportStep.done && state.result != null) _result(context, state.result!),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text(l.importStatements),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => StatementsPage(accountId: account.id))),
        ),
      ],
    );
  }

  Future<void> _choose(BuildContext context, Account account) async {
    final cubit = context.read<ImportCubit>();
    final file = await context.read<AppServices>().files.pickStatement();
    if (file == null) return;
    await cubit.importFile(account.id, file.bytes);
  }

  Widget _refusal(BuildContext context, ImportRefusal refusal) {
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: ListTile(
        leading: Icon(Icons.block, color: colors.onErrorContainer),
        title: Text(l.importRefusedTitle, style: TextStyle(color: colors.onErrorContainer)),
        subtitle: Text(
          refusalText(l, refusal),
          key: const Key('importRefusal'),
          style: TextStyle(color: colors.onErrorContainer),
        ),
      ),
    );
  }

  Widget _result(BuildContext context, ImportResult result) {
    final l = AppLocalizations.of(context);
    final s = result.statement;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(l.importDoneTitle),
            subtitle: Text(
              '${l.importDonePeriod(formatDate(s.periodStart.toDateTime()), formatDate(s.periodEnd.toDateTime()))}\n'
              '${l.importDoneLines(result.lines, result.proposed, result.toComplete)}',
              key: const Key('importResult'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FilledButton.tonal(
              key: const Key('importValidate'),
              onPressed: () =>
                  Navigator.of(context)
                      .pushReplacement(MaterialPageRoute<void>(builder: (_) => const ValidationPage())),
              child: Text(l.validationAction),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmFirst(BuildContext context, ImportState state) async {
    final l = AppLocalizations.of(context);
    final cubit = context.read<ImportCubit>();
    final statement = state.pending!.response.statement;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.importFirstTitle),
        content: Text(
          l.importFirstBody(
            formatAmount(statement.openingBalance ?? 0),
            formatDate(statement.periodStart.toDateTime()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.importFirstConfirm)),
        ],
      ),
    );
    if (confirmed == true) {
      await cubit.confirmFirst();
    } else {
      cubit.again();
    }
  }
}

/// Asks the balance of the account for an export without balances.
Future<void> _askBalance(BuildContext context, ImportState state) async {
  final cubit = context.read<ImportCubit>();
  final balance = await showDialog<int>(
    context: context,
    builder: (_) => _BalanceDialog(preview: state.preview!),
  );
  if (balance != null) {
    await cubit.confirmBalance(balance);
  } else {
    cubit.again();
  }
}

/// The balance the bank shows now: the new lines must lead to it.
class _BalanceDialog extends StatefulWidget {
  const _BalanceDialog({required this.preview});

  final ImportPreview preview;

  @override
  State<_BalanceDialog> createState() => _BalanceDialogState();
}

class _BalanceDialogState extends State<_BalanceDialog> {
  final _balance = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _balance.dispose();
    super.dispose();
  }

  void _submit() {
    final cents = parseAmount(_balance.text);
    if (cents == null) {
      setState(() => _error = AppLocalizations.of(context).importBalanceInvalid);
      return;
    }
    Navigator.of(context).pop(cents);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final preview = widget.preview;
    return AlertDialog(
      title: Text(l.importBalanceTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.importBalanceLines(preview.newLines), key: const Key('importBalanceLines')),
          const SizedBox(height: 8),
          Text(preview.first ? l.importBalanceFirstHint : l.importBalanceNextHint),
          const SizedBox(height: 8),
          TextField(
            key: const Key('importBalance'),
            controller: _balance,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(labelText: l.importBalanceField, errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(key: const Key('importBalanceConfirm'), onPressed: _submit, child: Text(l.importFirstConfirm)),
      ],
    );
  }
}

/// The reason of a refusal, for the user.
String refusalText(AppLocalizations l, ImportRefusal refusal) {
  if (refusal.ledger case final e?) return ledgerErrorText(l, e);
  if (refusal.serverVersion case final version?) return l.importServerTooOld(version);
  return switch (refusal.code) {
    null => l.importUnreachable,
    'IMPORT_UNREADABLE' => l.importUnreadable,
    'IMPORT_UNKNOWN_FORMAT' => l.importUnknownFormat,
    'IMPORT_TOO_LARGE' => l.importTooLarge,
    'IMPORT_INCONSISTENT' => l.importInconsistent(switch (refusal.check) {
      'currency' => l.importCheckCurrency,
      'period' => l.importCheckPeriod,
      'runningBalance' => l.importCheckRunningBalance,
      'totals' => l.importCheckTotals,
      'closingBalance' => l.importCheckClosingBalance,
      _ => l.importCheckLayout,
    }),
    final code => l.importServerRefused(code),
  };
}
