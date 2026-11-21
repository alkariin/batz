import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ledger/category.dart';
import '../../domain/views/year_view.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../transactions/transaction_detail_page.dart';
import '../transactions/transaction_texts.dart';
import 'year_texts.dart';

/// The transactions that make an amount of the « Année » screen: a row of
/// the view, for the year or one month, with the part each one counts; each
/// opens its detail (step 4.5).
class CompositionPage extends StatelessWidget {
  const CompositionPage({
    super.key,
    required this.year,
    required this.kind,
    required this.row,
    required this.title,
    this.nature,
    this.month,
  });

  final int year;
  final ViewKind kind;
  final ViewRow row;
  final String title;

  /// The nature of the row, for the sign of the amounts (decision H7).
  final CategoryNature? nature;

  /// From 1 to 12; the whole year when null.
  final int? month;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final parts = ledger.views.composition(year, kind, row, month: month);
    final total = parts.fold(0, (sum, c) => sum + c.cents);
    final period = month == null ? '$year' : l.compositionPeriod(monthName(l, month!), '$year');
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        children: [
          ListTile(
            title: Text(period),
            subtitle: Text(kind == ViewKind.cash ? l.yearViewCash : l.yearViewEconomic),
            trailing: Text(
              shownAmount(total, nature),
              key: const Key('compositionTotal'),
              style: theme.textTheme.titleMedium,
            ),
          ),
          const Divider(),
          if (parts.isEmpty) ListTile(title: Text(l.compositionEmpty)),
          for (final part in parts)
            ListTile(
              key: ValueKey('composition-${part.transaction.id}'),
              title: Text(titleText(l, ledger, part.transaction)),
              subtitle: Text(
                [
                  formatDate(part.transaction.date.toDateTime()),
                  kindText(l, ledger.kindOf(part.transaction)),
                  if (part.cents != part.transaction.amount) formatAmount(part.transaction.amount),
                ].join(' · '),
              ),
              trailing: Text(shownAmount(part.cents, nature), style: theme.textTheme.bodyMedium),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => TransactionDetailPage(transactionId: part.transaction.id)),
              ),
            ),
        ],
      ),
    );
  }
}
