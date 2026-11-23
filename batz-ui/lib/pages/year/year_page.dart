import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/calendar_date.dart';
import '../../domain/ledger/category.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/views/year_view.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import '../modules/flow_page.dart';
import '../redistribution/redistribution_page.dart';
import '../shares/shares_page.dart';
import '../validation/validation_page.dart';
import 'composition_page.dart';
import 'year_texts.dart';

/// Width from which the months of the year are twelve columns; below, each
/// line unfolds its months.
const monthColumnsBreakpoint = 1100.0;

/// « Année »: the tree of a year with its amounts, in the cash-flow or the
/// economic view, month by month. Every amount opens the transactions that
/// make it.
class YearPage extends StatefulWidget {
  const YearPage({super.key, this.initialYear});

  final int? initialYear;

  @override
  State<YearPage> createState() => _YearPageState();
}

/// One line of the screen.
class _Line {
  const _Line({
    required this.key,
    required this.label,
    required this.depth,
    required this.amounts,
    this.nature,
    this.row,
    this.groupId,
    this.strong = false,
    this.secondary = false,
  });

  final String key;
  final String label;
  final int depth;
  final MonthlyAmounts amounts;
  final CategoryNature? nature;

  /// What its amounts are made of; null for a redistribution line.
  final ViewRow? row;

  /// For a group, its category: it folds.
  final String? groupId;
  final bool strong;
  final bool secondary;
}

class _YearPageState extends State<YearPage> {
  late int? _year = widget.initialYear;
  ViewKind _kind = ViewKind.economic;
  final _folded = <String>{};
  final _unfolded = <String>{};

  @override
  void initState() {
    super.initState();
    // The view chosen last on this device.
    context.read<AppServices>().preferences.viewKind().then((kind) {
      if (mounted) setState(() => _kind = kind);
    });
  }

  void _setKind(ViewKind kind) {
    setState(() => _kind = kind);
    context.read<AppServices>().preferences.setViewKind(kind);
  }

  List<_Line> _lines(AppLocalizations l, Ledger ledger, YearView view) {
    final tree = view.tree;
    final lines = <_Line>[];

    void visit(Category category, int depth) {
      final children = tree.childrenOf(category.id);
      final group = children.isNotEmpty || category.isTopLevel;
      final nature = tree.natureOf(category.id);
      lines.add(
        _Line(
          key: category.id,
          label: category.name,
          depth: depth,
          amounts: view.categories[category.id]!,
          nature: nature,
          row: CategoryRow(category.id),
          groupId: group ? category.id : null,
          strong: group,
        ),
      );
      if (_folded.contains(category.id)) return;
      for (final line in view.redistributions) {
        if (line.rule.sourceId == category.id) {
          lines.add(
            _Line(
              key: 'redistribution-${line.rule.id}-source',
              label: l.yearRedistributionTo(
                tree.byId[line.rule.targetId]?.name ?? '?',
                redistributionValueText(l, line.rule),
              ),
              depth: depth + 1,
              amounts: -line.moved,
              nature: nature,
              secondary: true,
            ),
          );
        }
        if (line.rule.targetId == category.id) {
          lines.add(
            _Line(
              key: 'redistribution-${line.rule.id}-target',
              label: l.yearRedistributionFrom(
                tree.byId[line.rule.sourceId]?.name ?? '?',
                redistributionValueText(l, line.rule),
              ),
              depth: depth + 1,
              amounts: line.moved,
              nature: nature,
              secondary: true,
            ),
          );
        }
      }
      for (final child in children) {
        visit(child, depth + 1);
      }
    }

    final roots = tree.roots;
    for (final (index, root) in roots.indexed) {
      visit(root, 0);
      // « À classer » follows the last top-level group of its nature.
      final nature = root.nature!;
      final last = !roots.skip(index + 1).any((r) => r.nature == nature);
      final toClassify = view.toClassify[nature]!;
      if (last && !toClassify.isZero) {
        lines.add(
          _Line(
            key: 'toClassify-${nature.name}',
            label: l.yearToClassifyNature(natureText(l, nature)),
            depth: 0,
            amounts: toClassify,
            nature: nature,
            row: ToClassifyRow(nature),
            strong: true,
          ),
        );
      }
    }
    if (!view.unclassified.isZero) {
      lines.add(
        _Line(
          key: 'unclassified',
          label: l.yearUnclassified,
          depth: 0,
          amounts: view.unclassified,
          row: const UnclassifiedRow(),
          strong: true,
        ),
      );
    }
    return lines;
  }

  void _open(BuildContext context, int year, _Line line, {int? month}) {
    final row = line.row;
    if (row == null) return;
    // « À classer » leads to the questions of the year.
    if (row is ToClassifyRow) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SharesPage(year: year)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CompositionPage(year: year, kind: _kind, row: row, title: line.label, nature: line.nature, month: month),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final views = ledger.views;
    final today = CalendarDate.today().year;
    final years = views.years(currentYear: today);
    if (years.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.navYear)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.yearNone, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final year = years.contains(_year) ? _year! : (years.contains(today) ? today : years.last);
    final view = views.of(year, _kind)!;
    final lines = _lines(l, ledger, view);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.navYear)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= monthColumnsBreakpoint;
          return ListView(
            key: const Key('yearList'),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<int>(
                      key: const Key('yearPick'),
                      value: year,
                      items: [for (final y in years.reversed) DropdownMenuItem(value: y, child: Text('$y'))],
                      onChanged: (y) => setState(() => _year = y),
                    ),
                    SegmentedButton<ViewKind>(
                      key: const Key('viewKind'),
                      segments: [
                        ButtonSegment(value: ViewKind.cash, label: Text(l.yearViewCash)),
                        ButtonSegment(value: ViewKind.economic, label: Text(l.yearViewEconomic)),
                      ],
                      selected: {_kind},
                      onSelectionChanged: (s) => _setKind(s.single),
                    ),
                    OutlinedButton.icon(
                      key: const Key('yearFlow'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FlowPage(year: year, initialKind: _kind),
                        ),
                      ),
                      icon: const Icon(Icons.account_tree_outlined),
                      label: Text(l.flowButton),
                    ),
                  ],
                ),
              ),
              _Header(view: view),
              if (view.isPreview) _Notice(l.yearPreview('$year')),
              if (view.inapplicable.isNotEmpty)
                _Notice(
                  l.yearInapplicable(view.inapplicable.length),
                  key: const Key('yearInapplicable'),
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => RedistributionPage(initialYear: year))),
                ),
              if (view.linesToValidate > 0)
                _Notice(
                  l.yearToValidate(view.linesToValidate),
                  key: const Key('yearToValidate'),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ValidationPage())),
                ),
              if (wide)
                _MonthHeader(l: l)
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(l.yearCostsHint, style: theme.textTheme.bodySmall),
                ),
              for (final line in lines) wide ? _wideLine(context, l, year, line) : _narrowLine(context, l, year, line),
            ],
          );
        },
      ),
    );
  }

  Widget _label(BuildContext context, _Line line) {
    final theme = Theme.of(context);
    final style = line.strong
        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
        : line.secondary
        ? theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)
        : theme.textTheme.bodyMedium;
    return Row(
      children: [
        SizedBox(width: 16.0 * line.depth),
        if (line.groupId != null)
          InkWell(
            key: ValueKey('yearFold-${line.key}'),
            onTap: () => setState(() {
              if (!_folded.remove(line.groupId)) _folded.add(line.groupId!);
            }),
            child: Icon(_folded.contains(line.groupId) ? Icons.chevron_right : Icons.expand_more, size: 20),
          )
        else
          const SizedBox(width: 20),
        const SizedBox(width: 4),
        Expanded(
          child: Text(line.label, style: style, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  /// Twelve columns and the total (wide screens).
  Widget _wideLine(BuildContext context, AppLocalizations l, int year, _Line line) {
    final style = line.strong
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
        : Theme.of(context).textTheme.bodySmall;
    Widget cell(String key, int cents, {int? month}) => Expanded(
      child: InkWell(
        key: ValueKey(key),
        onTap: line.row == null ? null : () => _open(context, year, line, month: month),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Text(
            cents == 0 ? '–' : shownAmount(cents, line.nature),
            textAlign: TextAlign.right,
            style: style,
            maxLines: 1,
          ),
        ),
      ),
    );
    return Padding(
      key: ValueKey('yearLine-${line.key}'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 3, child: _label(context, line)),
          for (var m = 1; m <= 12; m++) cell('yearMonth-${line.key}-$m', line.amounts.month(m), month: m),
          cell('yearAmount-${line.key}', line.amounts.total),
        ],
      ),
    );
  }

  /// The total, the months unfolding below (narrow screens).
  Widget _narrowLine(BuildContext context, AppLocalizations l, int year, _Line line) {
    final theme = Theme.of(context);
    final unfolded = _unfolded.contains(line.key);
    final style = line.strong ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) : null;
    return Column(
      key: ValueKey('yearLine-${line.key}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: line.row == null ? null : () => _open(context, year, line),
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Expanded(child: _label(context, line)),
                Text(
                  shownAmount(line.amounts.total, line.nature),
                  key: ValueKey('yearAmount-${line.key}'),
                  style: style,
                ),
                IconButton(
                  key: ValueKey('yearMonths-${line.key}'),
                  tooltip: l.yearMonthDetail,
                  icon: Icon(unfolded ? Icons.expand_less : Icons.calendar_view_month_outlined, size: 20),
                  onPressed: () => setState(() {
                    if (!_unfolded.remove(line.key)) _unfolded.add(line.key);
                  }),
                ),
              ],
            ),
          ),
        ),
        if (unfolded)
          Padding(
            padding: EdgeInsets.only(left: 40.0 + 16.0 * line.depth, right: 56),
            child: Column(
              children: [
                for (var m = 1; m <= 12; m++)
                  InkWell(
                    key: ValueKey('yearMonth-${line.key}-$m'),
                    onTap: line.row == null ? null : () => _open(context, year, line, month: m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(monthName(l, m), style: theme.textTheme.bodySmall)),
                          Text(
                            line.amounts.month(m) == 0 ? '–' : shownAmount(line.amounts.month(m), line.nature),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Income, expenses, savings; « Non classé » when there is any; the period
/// offsets in the economic view.
class _Header extends StatelessWidget {
  const _Header({required this.view});

  final YearView view;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget figure(String key, String label, String amount) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(amount, key: ValueKey(key), style: theme.textTheme.titleMedium),
        ],
      ),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                figure('yearIncome', l.yearIncome, shownAmount(view.income.total, CategoryNature.income)),
                figure('yearExpenses', l.yearExpenses, shownAmount(view.expenses.total, CategoryNature.expense)),
                figure('yearSavings', l.yearSavings, formatAmount(view.savings.total)),
                if (!view.unclassified.isZero)
                  figure('yearUnclassified', l.yearUnclassified, formatAmount(view.unclassified.total)),
                if (view.kind == ViewKind.economic) ...[
                  const Divider(),
                  Text(l.yearOffsets, style: theme.textTheme.labelLarge),
                  figure(
                    'yearPaidForOtherYears',
                    l.yearPaidForOtherYears('${view.year}'),
                    formatAmount(view.paidForOtherYears, explicitPlus: true),
                  ),
                  figure(
                    'yearPaidInOtherYears',
                    l.yearPaidInOtherYears('${view.year}'),
                    formatAmount(view.paidInOtherYears, explicitPlus: true),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(l.yearCostsHint, style: Theme.of(context).textTheme.bodySmall)),
          for (var m = 1; m <= 12; m++)
            Expanded(
              child: Text(monthName(l, m), textAlign: TextAlign.right, style: style),
            ),
          Expanded(
            child: Text(l.yearTotal, textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {super.key, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: colors.secondaryContainer,
      child: ListTile(
        dense: true,
        title: Text(text, style: TextStyle(color: colors.onSecondaryContainer)),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
