import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/app_localizations.dart';
import 'home/home_page.dart';
import 'ledger_cubit.dart';
import 'more/more_page.dart';
import 'sync/sync_cubit.dart';
import 'transactions/transactions_page.dart';
import 'wealth/wealth_page.dart';
import 'year/year_page.dart';

/// Lets a page of the shell show another section (the key figures of the
/// home screen open « Année »).
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.select, required super.child});

  final void Function(Section section) select;

  static ShellScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

/// Width from which navigation moves from the bottom bar to a side rail.
const wideLayoutBreakpoint = 600.0;

/// The five top-level sections (specification, 4.6).
enum Section { home, transactions, year, wealth, more }

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations) label;
}

const _destinations = {
  Section.home: _Destination(Icons.home_outlined, Icons.home, _home),
  Section.transactions: _Destination(Icons.receipt_long_outlined, Icons.receipt_long, _transactions),
  Section.year: _Destination(Icons.calendar_month_outlined, Icons.calendar_month, _year),
  Section.wealth: _Destination(Icons.account_balance_outlined, Icons.account_balance, _wealth),
  Section.more: _Destination(Icons.more_horiz, Icons.more_horiz, _more),
};

String _home(AppLocalizations l) => l.navHome;
String _transactions(AppLocalizations l) => l.navTransactions;
String _year(AppLocalizations l) => l.navYear;
String _wealth(AppLocalizations l) => l.navWealth;
String _more(AppLocalizations l) => l.navMore;

/// Top-level layout: a bottom navigation bar on narrow screens, a side rail on
/// wide ones, and the page of the selected section.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Section _selected = Section.home;

  /// Synchronises when the app comes back to the foreground, and only
  /// periodically while it is shown (decision H2 of phase 2).
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final sync = context.read<SyncCubit>();
    _lifecycle = AppLifecycleListener(onResume: sync.resumed, onHide: sync.paused);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _select(int index) => setState(() => _selected = Section.values[index]);

  /// The icon of [section]: Transactions carries the number of lines to
  /// validate (specification, 4.4).
  Widget _icon(Section section, IconData icon, int toValidate) {
    if (section != Section.transactions || toValidate == 0) return Icon(icon);
    return Badge(key: const Key('toValidateBadge'), label: Text('$toValidate'), child: Icon(icon));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final toValidate = context.select<LedgerCubit, int>((c) => c.state.ledger.linesToValidate.length);
    final page = KeyedSubtree(
      key: ValueKey(_selected),
      child: switch (_selected) {
        Section.home => const HomePage(),
        Section.transactions => const TransactionsPage(),
        Section.year => const YearPage(),
        Section.wealth => const WealthPage(),
        Section.more => const MorePage(),
      },
    );
    return ShellScope(select: (section) => _select(section.index), child: _layout(l, page, toValidate));
  }

  Widget _layout(AppLocalizations l, Widget page, int toValidate) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < wideLayoutBreakpoint) {
          return Scaffold(
            body: page,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selected.index,
              onDestinationSelected: _select,
              destinations: [
                for (final MapEntry(key: section, value: d) in _destinations.entries)
                  NavigationDestination(
                    icon: _icon(section, d.icon, toValidate),
                    selectedIcon: _icon(section, d.selectedIcon, toValidate),
                    label: d.label(l),
                  ),
              ],
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  selectedIndex: _selected.index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final MapEntry(key: section, value: d) in _destinations.entries)
                      NavigationRailDestination(
                        icon: _icon(section, d.icon, toValidate),
                        selectedIcon: _icon(section, d.selectedIcon, toValidate),
                        label: Text(d.label(l)),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: page),
            ],
          ),
        );
      },
    );
  }
}
