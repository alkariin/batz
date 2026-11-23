import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/date_field.dart';
import '../../domain/ledger/debt.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/transaction.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import 'debt_form_page.dart';

/// One debt in a few words: its person and total, its direction and state.
Widget debtTile(BuildContext context, Debt debt, {required String relation}) {
  final l = AppLocalizations.of(context);
  return ListTile(
    key: ValueKey('linkedDebt-${debt.id}'),
    dense: true,
    leading: const Icon(Icons.handshake_outlined),
    title: Text('${debt.person} · ${formatAmount(debt.total)}'),
    subtitle: Text(
      [
        debt.direction == DebtDirection.owedToMe ? l.debtOwedToMe : l.debtIOwe,
        if (debt.repaid) l.debtRepaid,
        relation,
      ].join(' · '),
    ),
    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DebtFormPage(debt: debt))),
  );
}

/// Asks which open debt [transaction] repays, then records it. Returns
/// whether a debt was repaid.
Future<bool> repayDebtWith(BuildContext context, LedgerTransaction transaction) async {
  final l = AppLocalizations.of(context);
  final ledger = context.read<LedgerCubit>().state.ledger;
  final debt = await showDialog<Debt>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l.debtRepayTitle),
      children: [
        for (final debt in ledger.debtsRepayableBy(transaction))
          SimpleDialogOption(
            key: ValueKey('repayable-${debt.id}'),
            onPressed: () => Navigator.of(context).pop(debt),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${debt.person} · ${formatAmount(debt.total)}'),
              subtitle: Text(
                [
                  if (debt.description.isNotEmpty) debt.description,
                  l.debtSince(DateField.text(debt.start)),
                ].join(' · '),
              ),
            ),
          ),
      ],
    ),
  );
  if (debt == null || !context.mounted) return false;
  final today = context.read<AppServices>().today();
  final repaid = await applyToLedger(context, (ledger) => ledger.repayDebt(debt.id, transaction.id, today: today));
  if (repaid && context.mounted) showMessage(context, l.debtRepaidDone(debt.person));
  return repaid;
}

/// The debts of a transaction on its screen: those it gave rise to, those
/// it repaid, and the buttons that create one or repay one.
List<Widget> transactionDebts(BuildContext context, Ledger ledger, LedgerTransaction t) {
  if (t.isValidated && t.isTransfer) return const [];
  final l = AppLocalizations.of(context);
  final from = ledger.debtsFrom(t.id), repaid = ledger.debtsRepaidBy(t.id);
  final repayable = ledger.debtsRepayableBy(t);
  return [
    const Divider(),
    ListTile(title: Text(l.debtsTitle, style: Theme.of(context).textTheme.titleMedium)),
    for (final debt in from) debtTile(context, debt, relation: l.debtFromThis),
    for (final debt in repaid) debtTile(context, debt, relation: l.debtRepaidByThis),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            key: const Key('createDebt'),
            icon: const Icon(Icons.add),
            label: Text(l.debtCreateFromTransaction),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DebtFormPage(source: t))),
          ),
          if (repayable.isNotEmpty)
            OutlinedButton.icon(
              key: const Key('repayDebt'),
              icon: const Icon(Icons.done_all),
              label: Text(l.debtRepayWithTransaction),
              onPressed: () => repayDebtWith(context, t),
            ),
        ],
      ),
    ),
  ];
}
