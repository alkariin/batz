import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../accounts/accounts_page.dart';
import '../server/server_cubit.dart';
import '../server/server_page.dart';

/// "Plus": settings and secondary screens.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navMore)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(l.accountsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountsPage())),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(l.serverTitle),
            subtitle: BlocBuilder<ServerCubit, ServerState>(
              builder: (context, state) => Text(state.paired ? l.serverPaired : l.serverNotPaired),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ServerPage())),
          ),
        ],
      ),
    );
  }
}
