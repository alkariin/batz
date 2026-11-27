import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ledger/transfer_pairs.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import 'transaction_detail_page.dart';
import 'transaction_texts.dart';

/// The validated transfers between two imported accounts whose line on the
/// other account is not found, each leading to its screen.
class UnpairedTransfersPage extends StatelessWidget {
  const UnpairedTransfersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final transfers = ledger.unpairedTransfers;
    return Scaffold(
      appBar: AppBar(title: Text(l.unpairedTitle)),
      body: ListView(
        children: [
          ListTile(subtitle: Text(l.unpairedHint(pairWindowDays))),
          if (transfers.isEmpty) ListTile(title: Text(l.unpairedEmpty)),
          for (final t in transfers)
            ListTile(
              key: ValueKey('unpaired-${t.id}'),
              leading: const Icon(Icons.swap_horiz),
              title: Text(titleText(l, ledger, t)),
              subtitle: Text('${formatDate(t.date.toDateTime())} · ${accountsText(l, ledger, t)}'),
              trailing: Text(formatAmount(t.amount), style: Theme.of(context).textTheme.titleSmall),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => TransactionDetailPage(transactionId: t.id))),
            ),
        ],
      ),
    );
  }
}
