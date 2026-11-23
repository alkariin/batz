import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../accounts/accounts_page.dart';
import '../categories/categories_page.dart';
import '../export/export_page.dart';
import '../modules/electricity_page.dart';
import '../modules/salary_page.dart';
import '../modules/subscriptions_page.dart';
import '../modules/taxes_page.dart';
import '../modules/vacations_page.dart';
import '../redistribution/redistribution_page.dart';
import '../server/server_cubit.dart';
import '../server/server_page.dart';
import '../../version.dart';

/// « Plus »: the analyses (the modules), the subscriptions, then the settings.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navMore)),
      body: ListView(
        children: [
          _Section(l.moreAnalyses),
          ListTile(
            key: const Key('moreSalary'),
            leading: const Icon(Icons.badge_outlined),
            title: Text(l.salaryTitle),
            subtitle: Text(l.salaryMenuHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SalaryPage())),
          ),
          ListTile(
            key: const Key('moreTaxes'),
            leading: const Icon(Icons.account_balance_outlined),
            title: Text(l.taxesTitle),
            subtitle: Text(l.taxesMenuHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TaxesPage())),
          ),
          ListTile(
            key: const Key('moreVacations'),
            leading: const Icon(Icons.luggage_outlined),
            title: Text(l.vacationsTitle),
            subtitle: Text(l.vacationsMenuHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VacationsPage())),
          ),
          ListTile(
            key: const Key('moreElectricity'),
            leading: const Icon(Icons.bolt_outlined),
            title: Text(l.electricityTitle),
            subtitle: Text(l.electricityMenuHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ElectricityPage())),
          ),
          const Divider(),
          ListTile(
            key: const Key('moreSubscriptions'),
            leading: const Icon(Icons.autorenew),
            title: Text(l.subscriptionsTitle),
            subtitle: Text(l.subscriptionsMenuHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionsPage())),
          ),
          const Divider(),
          _Section(l.moreSettings),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(l.accountsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountsPage())),
          ),
          ListTile(
            key: const Key('moreCategories'),
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(l.categoriesTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CategoriesPage())),
          ),
          ListTile(
            key: const Key('moreRedistribution'),
            leading: const Icon(Icons.call_split),
            title: Text(l.redistributionMenu),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RedistributionPage())),
          ),
          ListTile(
            key: const Key('moreExport'),
            leading: const Icon(Icons.file_download_outlined),
            title: Text(l.exportMenu),
            subtitle: Text(l.exportMenuHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExportPage())),
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
          // The version installed on this device: what an update changes.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.moreVersion(appVersion),
              key: const Key('moreVersion'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
