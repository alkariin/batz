import 'package:flutter/material.dart';

import '../components/empty_page.dart';
import '../l10n/app_localizations.dart';

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

  void _select(int index) => setState(() => _selected = Section.values[index]);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final page = KeyedSubtree(
      key: ValueKey(_selected),
      child: EmptyPage(title: _destinations[_selected]!.label(l)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < wideLayoutBreakpoint) {
          return Scaffold(
            body: page,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selected.index,
              onDestinationSelected: _select,
              destinations: [
                for (final d in _destinations.values)
                  NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label(l)),
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
                    for (final d in _destinations.values)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
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
