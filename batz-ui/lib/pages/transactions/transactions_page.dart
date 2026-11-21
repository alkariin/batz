import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/calendar_date.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/transaction.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../import/import_page.dart';
import '../ledger_cubit.dart';
import 'entry_form_page.dart';
import 'transaction_detail_page.dart';
import 'transaction_texts.dart';
import 'transfer_form_page.dart';

/// Transactions: the list, most recent first, filtered by account and year.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String? _accountId;
  int? _year;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<LedgerCubit, LedgerState>(
      builder: (context, state) {
        final ledger = state.ledger;
        final accountId = ledger.accounts.containsKey(_accountId) ? _accountId : null;
        final years = {...ledger.yearsWithTransactions, CalendarDate.today().year, ?_year}.toList()..sort();
        final list = ledger.transactionList(accountId: accountId, year: _year);
        return Scaffold(
          appBar: AppBar(
            title: Text(l.navTransactions),
            actions: [
              IconButton(
                key: const Key('importStatement'),
                tooltip: l.importTitle,
                icon: const Icon(Icons.upload_file),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ImportPage())),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: l.transactionNew,
            onPressed: () => _create(context),
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String?>(
                        key: const Key('filterAccount'),
                        isExpanded: true,
                        value: accountId,
                        items: [
                          DropdownMenuItem(child: Text(l.transactionsAllAccounts)),
                          for (final a in ledger.sortedAccounts) DropdownMenuItem(value: a.id, child: Text(a.name)),
                        ],
                        onChanged: (id) => setState(() => _accountId = id),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<int?>(
                      key: const Key('filterYear'),
                      value: _year,
                      items: [
                        DropdownMenuItem(child: Text(l.transactionsAllYears)),
                        for (final y in years.reversed) DropdownMenuItem(value: y, child: Text('$y')),
                      ],
                      onChanged: (y) => setState(() => _year = y),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(child: Text(l.transactionsEmpty))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: list.length,
                        itemBuilder: (context, i) => _tile(context, ledger, list[i], accountId),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, Ledger ledger, LedgerTransaction t, String? accountId) {
    final l = AppLocalizations.of(context);
    final kind = ledger.kindOf(t);
    // Seen from the arrival account, a transfer brings money in.
    final amount = t.isTransfer && accountId == t.counterpartAccountId ? -t.amount : t.amount;
    final category = ledger.categoryOf(t);
    return ListTile(
      leading: Icon(_icon(kind)),
      title: Text(titleText(l, ledger, t)),
      subtitle: Text(
        [
          formatDate(t.date.toDateTime()),
          kindText(l, kind),
          if (category != null && t.description.isNotEmpty) category.name,
          accountsText(l, ledger, t),
        ].join(' · '),
      ),
      trailing: Text(formatAmount(amount), style: Theme.of(context).textTheme.titleSmall),
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => TransactionDetailPage(transactionId: t.id))),
    );
  }

  static IconData _icon(TransactionKind? kind) => switch (kind) {
    TransactionKind.expense => Icons.south_east,
    TransactionKind.refund => Icons.undo,
    TransactionKind.income => Icons.north_west,
    TransactionKind.transfer => Icons.swap_horiz,
    null => Icons.help_outline,
  };

  Future<void> _create(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l.transactionNewEntry),
              onTap: () => Navigator.of(context).pop(false),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(l.transactionNewTransfer),
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => choice ? const TransferFormPage() : const EntryFormPage()));
  }
}
