import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/refund.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../transactions/transaction_texts.dart';

/// Finds the expense a refund is attached to: validated expenses of any
/// account and any year, by text and by amount, each line of a split
/// expense apart. Returns the identifier of the line.
class RefundTargetPage extends StatefulWidget {
  const RefundTargetPage({super.key, this.excludeTransactionId});

  /// The refund itself, never offered.
  final String? excludeTransactionId;

  @override
  State<RefundTargetPage> createState() => _RefundTargetPageState();
}

class _RefundTargetPageState extends State<RefundTargetPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final expenses = [
      for (final expense in ledger.refundTargets(_search.text))
        if (expense.transaction.id != widget.excludeTransactionId) expense,
    ].take(200).toList();
    return Scaffold(
      appBar: AppBar(title: Text(l.refundPick)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('refundSearch'),
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.refundSearch,
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: expenses.isEmpty
                ? Center(child: Text(l.refundNoExpense))
                : ListView.builder(
                    itemCount: expenses.length,
                    itemBuilder: (context, i) => expenseTile(
                      context,
                      ledger,
                      expenses[i],
                      key: ValueKey('refundTarget-${expenses[i].line.id}'),
                      onTap: () => Navigator.of(context).pop(expenses[i].line.id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// An expense line in a few words: description, date, category, account,
/// amount; for a line of a split expense, its own category and amount, then
/// the amount of the whole expense.
Widget expenseTile(BuildContext context, Ledger ledger, LineOf expense, {Key? key, VoidCallback? onTap}) {
  final l = AppLocalizations.of(context);
  final (:line, transaction: t) = expense;
  final category = ledger.categories[line.categoryId];
  return ListTile(
    key: key,
    leading: const Icon(Icons.south_east),
    title: Text(titleText(l, ledger, t)),
    subtitle: Text(
      [
        formatDate(t.date.toDateTime()),
        ?category?.name,
        accountsText(l, ledger, t),
        if (t.isSplit) l.refundSplitOf(formatAmount(t.amount)),
      ].join(' · '),
    ),
    trailing: Text(formatAmount(line.amount)),
    onTap: onTap,
  );
}
