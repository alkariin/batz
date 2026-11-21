import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/date_field.dart';
import '../../domain/calendar_date.dart';
import '../../domain/views/wealth.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import '../validation/validation_page.dart';
import '../year/year_page.dart';
import 'account_page.dart';
import 'wealth_curve.dart';

/// « Fortune » (specification, 4.6; step 5.4): the net wealth of the day and
/// its change since 31 December, the accounts by type with their balance
/// and its date, the debts, the monthly curve, and the table that explains
/// the change of a year.
class WealthPage extends StatefulWidget {
  const WealthPage({super.key});

  @override
  State<WealthPage> createState() => _WealthPageState();
}

class _WealthPageState extends State<WealthPage> {
  int? _year;
  final _unfolded = <String>{};

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final today = context.read<AppServices>().today();
    final wealth = ledger.wealth(today);
    final now = wealth.at(today);
    final years = wealth.years;
    final yearStart = CalendarDate(today.year - 1, 12, 31);

    return Scaffold(
      appBar: AppBar(title: Text(l.navWealth)),
      body: ListView(
        key: const Key('wealthList'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Constrained(
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.wealthNet, style: theme.textTheme.labelLarge),
                    Text(formatAmount(now.total), key: const Key('wealthNet'), style: theme.textTheme.headlineMedium),
                    Text(l.wealthAt(DateField.text(today)), style: theme.textTheme.bodySmall),
                    if (years.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Text(l.wealthSince(DateField.text(yearStart)))),
                          Text(
                            formatAmount(now.total - wealth.fortuneAt(yearStart), explicitPlus: true),
                            key: const Key('wealthSinceYearStart'),
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(l.wealthNone),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _Constrained(child: _accounts(context, l, now)),
          if (wealth.monthly.isNotEmpty)
            _Constrained(
              child: Card(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.wealthCurve, style: theme.textTheme.titleMedium),
                      Text(l.wealthCurveHint, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 12),
                      WealthCurve(months: wealth.monthly),
                    ],
                  ),
                ),
              ),
            ),
          if (years.isNotEmpty) _Constrained(child: _explanation(context, l, wealth, years)),
        ],
      ),
    );
  }

  /// The accounts by type, the debts, then the accounts without balance.
  Widget _accounts(BuildContext context, AppLocalizations l, WealthAt now) {
    final theme = Theme.of(context);
    final totals = now.totalsByType;
    Widget tile(AccountWealth a) {
      final statement = a.lastStatement;
      final declared = a.lastDeclared;
      final String? date;
      if (!a.inWealth) {
        date = null;
      } else if (statement != null && (declared == null || !statement.periodEnd.isBefore(declared.date))) {
        date = l.wealthStatementDate(DateField.text(statement.periodEnd));
      } else {
        date = l.wealthBalanceDate(DateField.text(a.lastPointDate!));
      }
      return ListTile(
        key: ValueKey('wealthAccount-${a.account.id}'),
        title: Text(a.account.name),
        subtitle: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(date ?? l.wealthWithoutBalance),
            if (a.isOld)
              Text(
                l.wealthOld,
                key: ValueKey('wealthOld-${a.account.id}'),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
              ),
          ],
        ),
        trailing: a.inWealth
            ? Text(
                formatAmount(a.balance!),
                key: ValueKey('wealthBalance-${a.account.id}'),
                style: theme.textTheme.titleSmall,
              )
            : const Icon(Icons.chevron_right),
        onTap: () => _push(AccountPage(accountId: a.account.id)),
      );
    }

    final without = [
      for (final a in now.accounts)
        if (!a.inWealth) a,
    ];
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final MapEntry(key: type, value: accounts) in now.byType.entries) ...[
            ListTile(
              dense: true,
              title: Text(accountTypeText(l, type), style: theme.textTheme.titleSmall),
              trailing: Text(
                formatAmount(totals[type]!),
                key: ValueKey('wealthType-${type.name}'),
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final a in accounts) tile(a),
            const Divider(height: 1),
          ],
          ListTile(
            key: const Key('wealthDebtsLine'),
            title: Text(l.wealthDebts, style: theme.textTheme.titleSmall),
            subtitle: Text(l.wealthDebtsHint),
            trailing: Text(formatAmount(now.debts), key: const Key('wealthDebts'), style: theme.textTheme.titleSmall),
          ),
          if (without.isNotEmpty) ...[
            const Divider(height: 1),
            ListTile(dense: true, title: Text(l.wealthWithoutBalanceSection, style: theme.textTheme.titleSmall)),
            for (final a in without) tile(a),
          ],
        ],
      ),
    );
  }

  /// The table of the year chosen (H8): each line computed for itself;
  /// the lines by account unfold, « Non classé » leads to the validation,
  /// the results to the « Année » screen.
  Widget _explanation(BuildContext context, AppLocalizations l, Wealth wealth, List<int> years) {
    final theme = Theme.of(context);
    final year = years.contains(_year) ? _year! : years.last;
    final table = wealth.explain(year);
    String signed(int cents) => formatAmount(cents, explicitPlus: true);
    String name(AccountAmount a) => a.account?.name ?? l.explainDeletedAccount;

    Widget line(
      String key,
      String label,
      String amount, {
      bool strong = false,
      VoidCallback? onTap,
      List<Widget> details = const [],
    }) {
      final unfolded = _unfolded.contains(key);
      final style = strong ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('explainLine-$key'),
            onTap: details.isNotEmpty
                ? () => setState(() {
                    if (!_unfolded.remove(key)) _unfolded.add(key);
                  })
                : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: style)),
                  Text(amount, key: ValueKey('explain-$key'), style: style),
                  SizedBox(
                    width: 28,
                    child: details.isNotEmpty
                        ? Icon(unfolded ? Icons.expand_less : Icons.expand_more, size: 20)
                        : onTap != null
                        ? const Icon(Icons.chevron_right, size: 20)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          if (unfolded) ...details,
        ],
      );
    }

    Widget detail(String key, String label, String amount) => Padding(
      key: ValueKey('explainDetail-$key'),
      padding: const EdgeInsets.only(left: 16, right: 28, bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          Text(amount, style: theme.textTheme.bodySmall),
        ],
      ),
    );

    List<Widget> byAccount(String line, List<AccountAmount> amounts) => [
      for (final a in amounts) detail('$line-${a.accountId}', name(a), signed(a.amount)),
    ];

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.wealthExplain, style: theme.textTheme.titleMedium)),
                DropdownButton<int>(
                  key: const Key('wealthYear'),
                  value: year,
                  items: [for (final y in years.reversed) DropdownMenuItem(value: y, child: Text('$y'))],
                  onChanged: (y) => setState(() => _year = y),
                ),
              ],
            ),
            Text(
              l.wealthExplainPeriod(DateField.text(table.start), DateField.text(table.end)),
              style: theme.textTheme.bodySmall,
            ),
            if (!table.hasView) Text(l.wealthNoTree, key: const Key('wealthNoTree'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            line(
              'economic',
              l.explainEconomic,
              formatAmount(table.economicResult),
              onTap: table.hasView ? () => _push(YearPage(initialYear: year)) : null,
            ),
            line('offsets', l.explainOffsets, signed(table.periodOffsets)),
            line(
              'cash',
              l.explainCash,
              formatAmount(table.cashResult),
              strong: true,
              onTap: table.hasView ? () => _push(YearPage(initialYear: year)) : null,
            ),
            const Divider(),
            line(
              'variations',
              l.explainVariations,
              signed(table.valueVariationsTotal),
              details: byAccount('variations', table.valueVariations),
            ),
            line(
              'added',
              l.explainAdded,
              signed(table.addedAccountsTotal),
              details: byAccount('added', table.addedAccounts),
            ),
            line(
              'debts',
              l.explainDebts,
              signed(table.debtsChange),
              details: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 28, bottom: 4),
                  child: Text(
                    l.explainDebtsDetail(
                      formatAmount(table.openDebtsAtStart),
                      formatAmount(table.openDebtsAtEnd),
                      signed(table.debtsAccountsMovements),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            line(
              'unclassified',
              l.explainUnclassified,
              signed(table.unclassified),
              onTap: () => _push(const ValidationPage()),
            ),
            // « Hors fortune » only when it is not zero (H3).
            if (table.outsideWealthTotal != 0)
              line(
                'outside',
                l.explainOutside,
                signed(table.outsideWealthTotal),
                details: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 28, bottom: 4),
                    child: Text(l.explainOutsideHint, style: theme.textTheme.bodySmall),
                  ),
                  ...byAccount('outside', table.outsideWealth),
                ],
              ),
            const Divider(),
            line('change', l.explainChange, signed(table.wealthChange), strong: true),
          ],
        ),
      ),
    );
  }
}

/// Keeps cards readable on a wide screen.
class _Constrained extends StatelessWidget {
  const _Constrained({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: child),
  );
}
