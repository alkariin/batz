import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/allocation.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/refund.dart';
import '../../domain/ledger/transaction.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import '../refunds/refund_target_page.dart';
import '../validation/classify_page.dart';
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

    // Imported lines keep the bank's amount, date and text (4.3).
    final editable = !(ledger.accounts[t.accountId]?.isDetailed ?? false) && !t.isImported;
    final line = t.line;
    // An attached refund follows the period of its expense (H3).
    final expense = ledger.expenseOf(t);
    final period = expense?.line ?? line;
    final shares = line == null || t.isTransfer || period == null
        ? null
        : allocate(line.amount, period.periodStart, period.periodEnd);
    final theme = Theme.of(context);

    Widget row(String label, String value) => ListTile(dense: true, title: Text(label), subtitle: Text(value));

    return Scaffold(
      appBar: AppBar(
        title: Text(l.detailTitle),
        actions: [
          // An imported line is classified again, its description and note
          // changed, from the classification screen (decision H4).
          if (t.isImported)
            IconButton(
              key: const Key('classifyImported'),
              tooltip: l.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<bool>(builder: (_) => ClassifyPage(transactionId: t.id))),
            ),
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
          if (t.rawText case final rawText?) row(l.fieldRawText, rawText),
          if (period != null && !t.isTransfer)
            row(
              l.detailPeriod,
              '${formatDate(period.periodStart.toDateTime())} – ${formatDate(period.periodEnd.toDateTime())}',
            ),
          ..._refund(context, ledger, t),
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

  /// The refunds of an expense and its net cost; the expense of a refund,
  /// or its broken link; attaching and detaching (decisions H3 and H4).
  List<Widget> _refund(BuildContext context, Ledger ledger, LedgerTransaction t) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final line = t.line;
    void open(String id) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TransactionDetailPage(transactionId: id)));
    if (line != null && ledger.isExpenseLine(t, line)) {
      final refunds = ledger.refundsOf(t);
      if (refunds.isEmpty) return const [];
      return [
        const Divider(),
        ListTile(title: Text(l.detailRefunds, style: theme.textTheme.titleMedium)),
        for (final refund in refunds)
          ListTile(
            key: ValueKey('refund-${refund.id}'),
            dense: true,
            leading: const Icon(Icons.undo),
            title: Text(titleText(l, ledger, refund)),
            subtitle: Text(formatDate(refund.date.toDateTime())),
            trailing: Text(formatAmount(refund.amount)),
            onTap: () => open(refund.id),
          ),
        ListTile(
          title: Text(l.detailNetCost),
          trailing: Text(
            formatAmount(ledger.netCostOf(t)),
            key: const Key('netCost'),
            style: theme.textTheme.titleMedium,
          ),
        ),
      ];
    }
    if (t.amount <= 0 || (t.isValidated && t.isTransfer)) return const [];
    final expense = ledger.expenseOf(t);
    final attached = line?.refundedLineId != null;
    return [
      const Divider(),
      if (expense != null) ...[
        ListTile(title: Text(l.detailRefundOf, style: theme.textTheme.titleMedium)),
        expenseTile(
          context,
          ledger,
          expense.transaction,
          key: const Key('refundedExpense'),
          onTap: () => open(expense.transaction.id),
        ),
      ] else if (attached)
        ListTile(
          leading: Icon(Icons.link_off, color: theme.colorScheme.error),
          title: Text(l.detailBrokenLink, style: TextStyle(color: theme.colorScheme.error)),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          children: [
            if (attached)
              OutlinedButton.icon(
                key: const Key('detachRefund'),
                icon: const Icon(Icons.link_off),
                label: Text(l.refundDetach),
                onPressed: () async {
                  if (await applyToLedger(context, (ledger) => ledger.detachRefund(t.id)) && context.mounted) {
                    showMessage(context, l.refundDetached);
                  }
                },
              ),
            if (expense == null)
              OutlinedButton.icon(
                key: const Key('attachRefund'),
                icon: const Icon(Icons.link),
                label: Text(l.refundAttach),
                onPressed: () async {
                  final lineId = await Navigator.of(context)
                      .push(MaterialPageRoute<String>(builder: (_) => RefundTargetPage(excludeTransactionId: t.id)));
                  if (lineId == null || !context.mounted) return;
                  if (await applyToLedger(context, (ledger) => ledger.attachRefund(t.id, lineId)) && context.mounted) {
                    showMessage(context, l.refundAttached);
                  }
                },
              ),
          ],
        ),
      ),
    ];
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
