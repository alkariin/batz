import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/allocation.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import 'entry_form_page.dart';
import 'transaction_texts.dart';
import 'transfer_form_page.dart';

/// One transaction: its fields and, for an expense or an income, its shares
/// per month and its total per year.
class TransactionDetailPage extends StatelessWidget {
  const TransactionDetailPage({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final t = ledger.transactions[transactionId];
    if (t == null) return Scaffold(appBar: AppBar(title: Text(l.detailTitle)));

    final editable = !(ledger.accounts[t.accountId]?.isDetailed ?? false);
    final line = t.line;
    final shares = line == null || t.isTransfer ? null : allocate(line.amount, line.periodStart, line.periodEnd);
    final theme = Theme.of(context);

    Widget row(String label, String value) => ListTile(dense: true, title: Text(label), subtitle: Text(value));

    return Scaffold(
      appBar: AppBar(
        title: Text(l.detailTitle),
        actions: [
          if (editable) ...[
            IconButton(
              tooltip: l.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => t.isTransfer ? TransferFormPage(transaction: t) : EntryFormPage(transaction: t),
                ),
              ),
            ),
            IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context)),
          ],
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(titleText(l, ledger, t), style: theme.textTheme.titleLarge),
            trailing: Text(formatAmount(t.amount), style: theme.textTheme.titleLarge),
          ),
          row(l.fieldDate, formatDate(t.date.toDateTime())),
          row(l.fieldAccount, accountsText(l, ledger, t)),
          row(l.detailType, kindText(l, ledger.kindOf(t))),
          if (ledger.categoryOf(t) case final category?) row(l.fieldCategory, category.name),
          if (t.description.isNotEmpty) row(l.fieldDescription, t.description),
          if (t.note.isNotEmpty) row(l.fieldNote, t.note),
          if (line != null && !t.isTransfer)
            row(
              l.detailPeriod,
              '${formatDate(line.periodStart.toDateTime())} – ${formatDate(line.periodEnd.toDateTime())}',
            ),
          if (shares != null) ...[
            const Divider(),
            ListTile(title: Text(l.detailYearTotals, style: theme.textTheme.titleMedium)),
            for (final entry in totalsByYear(shares).entries)
              ListTile(
                key: ValueKey('yearTotal-${entry.key}'),
                dense: true,
                title: Text('${entry.key}'),
                trailing: Text(formatAmount(entry.value)),
              ),
            const Divider(),
            ListTile(title: Text(l.detailShares, style: theme.textTheme.titleMedium)),
            for (final share in shares)
              ListTile(
                key: ValueKey('share-${share.month}'),
                dense: true,
                title: Text('${share.month.month.toString().padLeft(2, '0')}.${share.month.year}'),
                trailing: Text(formatAmount(share.cents)),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.transactionDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await applyToLedger(context, (ledger) => ledger.deleteTransaction(transactionId));
    if (deleted && context.mounted) {
      showMessage(context, l.transactionDeleted);
      Navigator.of(context).pop();
    }
  }
}
