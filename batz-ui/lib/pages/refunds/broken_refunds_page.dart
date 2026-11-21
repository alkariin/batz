import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ledger/refund.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../transactions/transaction_detail_page.dart';
import '../transactions/transaction_texts.dart';

/// The refunds whose expense is gone or no longer a validated expense:
/// each opens its detail, where it is detached or attached again.
class BrokenRefundsPage extends StatelessWidget {
  const BrokenRefundsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final refunds = ledger.brokenRefunds;
    return Scaffold(
      appBar: AppBar(title: Text(l.brokenRefundsTitle)),
      body: ListView(
        children: [
          ListTile(subtitle: Text(l.taskBrokenRefundsHint)),
          for (final t in refunds)
            ListTile(
              key: ValueKey('brokenRefund-${t.id}'),
              leading: const Icon(Icons.link_off),
              title: Text(titleText(l, ledger, t)),
              subtitle: Text('${formatDate(t.date.toDateTime())} · ${accountsText(l, ledger, t)}'),
              trailing: Text(formatAmount(t.amount)),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => TransactionDetailPage(transactionId: t.id))),
            ),
        ],
      ),
    );
  }
}
