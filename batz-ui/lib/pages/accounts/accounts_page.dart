import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ledger/account.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import 'account_form_page.dart';

/// Plus > Comptes: the list of accounts, active first, then archived.
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.accountsTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l.accountNew,
        onPressed: () => _open(context, null),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<LedgerCubit, LedgerState>(
        builder: (context, state) {
          final accounts = state.ledger.sortedAccounts;
          if (accounts.isEmpty) {
            return Center(
              child: Padding(padding: const EdgeInsets.all(24), child: Text(l.accountsEmpty)),
            );
          }
          final active = accounts.where((a) => !a.archived);
          final archived = accounts.where((a) => a.archived);
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final account in active) _tile(context, account),
              if (archived.isNotEmpty) ...[
                const Divider(),
                ListTile(dense: true, title: Text(l.accountsArchivedSection)),
                for (final account in archived) _tile(context, account),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, Account account) {
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(_icon(account.type)),
      title: Text(account.name),
      subtitle: Text([accountTypeText(l, account.type), if (account.isDetailed) l.accountDetailed].join(' · ')),
      onTap: () => _open(context, account),
    );
  }

  static void _open(BuildContext context, Account? account) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AccountFormPage(account: account)));
  }

  static IconData _icon(AccountType type) => switch (type) {
    AccountType.privateAccount => Icons.account_balance_outlined,
    AccountType.savings => Icons.savings_outlined,
    AccountType.pillar3 || AccountType.pillar2 => Icons.elderly_outlined,
    AccountType.investments => Icons.show_chart,
    AccountType.vehicle => Icons.directions_car_outlined,
    AccountType.rentDeposit => Icons.key_outlined,
    AccountType.cash => Icons.payments_outlined,
    AccountType.debts => Icons.handshake_outlined,
    AccountType.other => Icons.wallet_outlined,
  };
}
