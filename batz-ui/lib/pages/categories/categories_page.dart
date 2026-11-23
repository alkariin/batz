import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/calendar_date.dart';
import '../../domain/ids.dart';
import '../../domain/ledger/category.dart';
import '../../domain/ledger/issues.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/rule.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import '../validation/rule_form_page.dart';
import '../validation/rules_help.dart';

/// Plus > Catégories et règles: the tree of one year, each category with
/// the mapping rules that classify in it, then the transfer rules and the
/// rules whose target can no longer be used; and the creation of the trees.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, this.initialYear});

  /// Defaults to the current year.
  final int? initialYear;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late int _year = widget.initialYear ?? CalendarDate.today().year;

  /// The years offered: those with a tree, the current one, and the years
  /// just before the first tree and just after the last, whose tree can be
  /// created by hand.
  List<int> _years(Ledger ledger) {
    final years = {...ledger.yearsWithTree, ...ledger.forest.yearsWithDetached, CalendarDate.today().year, _year};
    if (ledger.yearsWithTree.isNotEmpty) {
      years.addAll([ledger.yearsWithTree.first - 1, ledger.yearsWithTree.last + 1]);
    }
    return years.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<LedgerCubit, LedgerState>(
      builder: (context, state) {
        final ledger = state.ledger;
        final tree = ledger.trees[_year];
        return Scaffold(
          appBar: AppBar(
            title: Text(l.categoriesTitle),
            actions: [
              const RulesHelpButton(),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DropdownButton<int>(
                  key: const Key('categoriesYear'),
                  value: _year,
                  underline: const SizedBox.shrink(),
                  items: [for (final y in _years(ledger)) DropdownMenuItem(value: y, child: Text('$y'))],
                  onChanged: (y) => setState(() => _year = y ?? _year),
                ),
              ),
            ],
          ),
          floatingActionButton: tree == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _addGroup(context),
                  icon: const Icon(Icons.add),
                  label: Text(l.categoriesNewGroup),
                ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (tree == null)
                _NoTree(year: _year, ledger: ledger)
              else ...[
                ..._TreeView(
                  tree: tree,
                  ledger: ledger,
                  duplicates: {
                    for (final issue in ledger.issues)
                      if (issue is DuplicateCategoryName && issue.year == _year)
                        for (final c in issue.categories) c.id,
                  },
                ).tiles(context),
                ..._transferSection(context, ledger),
                ..._unusableSection(context, ledger),
              ],
              ..._detachedSection(context, ledger, tree),
            ],
          ),
        );
      },
    );
  }

  /// « Transferts »: the transfer rules of the year whose account can be
  /// used, under the name of their account, and the button that adds one.
  List<Widget> _transferSection(BuildContext context, Ledger ledger) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unusable = {for (final r in ledger.unusableRules) r.id};
    final rules = [
      for (final r in ledger.rulesOf(_year))
        if (r.isTransfer && !unusable.contains(r.id)) r,
    ];
    return [
      const Divider(),
      ListTile(
        title: Text(l.categoriesTransfers, style: theme.textTheme.titleMedium),
        subtitle: Text(l.categoriesTransfersHint),
      ),
      for (final account in ledger.sortedAccounts)
        if (rules.any((r) => r.targetAccountId == account.id)) ...[
          ListTile(
            key: ValueKey('transferRules-${account.id}'),
            dense: true,
            contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
            title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          for (final rule in rules)
            if (rule.targetAccountId == account.id) _ruleTile(context, rule, depth: 1),
        ],
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton.icon(
            key: const Key('addTransferRule'),
            icon: const Icon(Icons.add),
            label: Text(l.categoriesAddTransferRule),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => RuleFormPage(
                  year: _year,
                  initial: RuleDraft(year: _year, lines: const []),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// The rules of the year whose category or account can no longer be
  /// used: they propose nothing until they get a target again.
  List<Widget> _unusableSection(BuildContext context, Ledger ledger) {
    final rules = [
      for (final r in ledger.unusableRules)
        if (r.year == _year) r,
    ];
    if (rules.isEmpty) return const [];
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return [
      const Divider(),
      ListTile(
        leading: Icon(Icons.warning_amber_outlined, color: theme.colorScheme.error),
        title: Text(l.categoriesUnusableRules, style: theme.textTheme.titleMedium),
        subtitle: Text(l.categoriesUnusableRulesHint),
      ),
      for (final rule in rules) _ruleTile(context, rule, depth: 1, chooseTarget: true),
    ];
  }

  /// « À replacer »: the detached categories of the year, each with the
  /// categories below it, and the action that moves it back into the tree.
  List<Widget> _detachedSection(BuildContext context, Ledger ledger, CategoryTree? tree) {
    final heads = ledger.forest.detachedHeads(_year);
    if (heads.isEmpty) return const [];
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rows = <Widget>[];
    void below(Category parent, int depth) {
      for (final child in ledger.forest.detachedChildrenOf(parent.id)) {
        rows.add(
          ListTile(
            key: ValueKey('detached-${child.id}'),
            dense: true,
            contentPadding: EdgeInsetsDirectional.only(start: 16.0 + 24.0 * depth, end: 4),
            title: Text(child.name),
          ),
        );
        below(child, depth + 1);
      }
    }

    for (final head in heads) {
      rows.add(
        ListTile(
          key: ValueKey('detached-${head.category.id}'),
          title: Text(head.category.name),
          subtitle: Text(detachReasonText(l, head.reason)),
          trailing: TextButton(
            key: Key('detachedMove-${head.category.name}'),
            onPressed: () => _moveDetached(context, head.category, tree),
            child: Text(l.categoryMove),
          ),
        ),
      );
      below(head.category, 1);
    }
    return [
      const Divider(),
      ListTile(
        title: Text(l.categoriesToReplace, style: theme.textTheme.titleMedium),
        subtitle: Text(l.categoriesToReplaceHint),
      ),
      ...rows,
    ];
  }

  Future<void> _moveDetached(BuildContext context, Category category, CategoryTree? tree) async {
    final target = await showDialog<_MoveTarget>(
      context: context,
      builder: (_) => _MoveDialog(tree: tree, category: category),
    );
    if (target == null || !context.mounted) return;
    await applyToLedger(
      context,
      (ledger) => ledger.moveCategory(category.id, parentId: target.parentId, nature: target.nature),
    );
  }

  Future<void> _addGroup(BuildContext context) async {
    final result = await showDialog<(String, CategoryNature)>(context: context, builder: (_) => const _GroupDialog());
    if (result == null || !context.mounted) return;
    await applyToLedger(
      context,
      (ledger) => ledger.addCategory(newId(), year: _year, name: result.$1, nature: result.$2),
    );
  }
}

class _NoTree extends StatelessWidget {
  const _NoTree({required this.year, required this.ledger});

  final int year;
  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final source = ledger.sourceYearFor(year);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.categoriesNoTree(year), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              source == null ? l.categoriesNoTreeDefault(year) : l.categoriesNoTreeCopy(source, year),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => applyToLedger(context, (ledger) => ledger.createTree(year)),
              child: Text(l.categoriesCreateTree(year)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Action { addRule, addChild, rename, move, up, down, delete }

/// One rule, under its category or its account: its lines, one per line;
/// a tap opens it.
Widget _ruleTile(BuildContext context, MappingRule rule, {required int depth, bool chooseTarget = false}) => ListTile(
  key: ValueKey('rule-${rule.id}'),
  dense: true,
  contentPadding: EdgeInsetsDirectional.only(start: 16.0 + 24.0 * depth, end: 16),
  leading: const Icon(Icons.rule, size: 18),
  minLeadingWidth: 18,
  title: Text(rule.lines.join('\n')),
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute<bool>(
      builder: (_) => RuleFormPage(year: rule.year, rule: rule, chooseTarget: chooseTarget),
    ),
  ),
);

class _TreeView {
  _TreeView({required this.tree, required this.ledger, this.duplicates = const {}});

  final CategoryTree tree;
  final Ledger ledger;

  /// Categories whose name another category of the year also has, after a
  /// merge.
  final Set<String> duplicates;

  /// The menu of each category, opened by its button or by a tap on the
  /// category.
  final _menus = <String, GlobalKey<PopupMenuButtonState<_Action>>>{};

  List<Widget> tiles(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tiles = <Widget>[];
    for (final category in tree.ordered) {
      final menu = _menus[category.id] = GlobalKey<PopupMenuButtonState<_Action>>();
      final depth = tree.depthOf(category.id);
      final assignable = tree.canHoldTransactions(category.id);
      tiles.add(
        ListTile(
          key: ValueKey(category.id),
          contentPadding: EdgeInsetsDirectional.only(start: 16.0 + 24.0 * depth, end: 4),
          title: Text(category.name, style: category.isTopLevel ? const TextStyle(fontWeight: FontWeight.w600) : null),
          leading: duplicates.contains(category.id)
              ? Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error)
              : null,
          subtitle: duplicates.contains(category.id)
              ? Text(l.categoryDuplicateName)
              : category.isTopLevel
              ? Text(natureText(l, category.nature!))
              : null,
          onTap: () => menu.currentState?.showButtonMenu(),
          trailing: PopupMenuButton<_Action>(
            key: menu,
            onSelected: (action) => _run(context, category, action),
            itemBuilder: (_) => [
              if (assignable)
                PopupMenuItem(
                  key: Key('categoryAddRule-${category.name}'),
                  value: _Action.addRule,
                  child: Text(l.categoryAddRule),
                ),
              PopupMenuItem(value: _Action.addChild, child: Text(l.categoryAddChild)),
              PopupMenuItem(value: _Action.rename, child: Text(l.categoryRename)),
              PopupMenuItem(value: _Action.move, child: Text(l.categoryMove)),
              PopupMenuItem(value: _Action.up, child: Text(l.categoryMoveUp)),
              PopupMenuItem(value: _Action.down, child: Text(l.categoryMoveDown)),
              PopupMenuItem(value: _Action.delete, child: Text(l.delete)),
            ],
            child: Padding(
              key: Key('categoryMenu-${category.name}'),
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.more_vert),
            ),
          ),
        ),
      );
      if (assignable) {
        for (final rule in ledger.rulesOfCategory(category.year, category.id)) {
          tiles.add(_ruleTile(context, rule, depth: depth + 1));
        }
      }
    }
    return tiles;
  }

  Future<void> _run(BuildContext context, Category category, _Action action) async {
    final l = AppLocalizations.of(context);
    switch (action) {
      case _Action.addRule:
        await Navigator.of(context).push(
          MaterialPageRoute<bool>(
            builder: (_) => RuleFormPage(
              year: category.year,
              initial: RuleDraft(year: category.year, lines: const [], targetCategoryId: category.id),
            ),
          ),
        );
      case _Action.addChild:
        final name = await _askName(context, l.categoryAddChild, '');
        if (name == null || !context.mounted) return;
        await applyToLedger(
          context,
          (ledger) => ledger.addCategory(newId(), year: category.year, name: name, parentId: category.id),
        );
      case _Action.rename:
        final name = await _askName(context, l.categoryRename, category.name);
        if (name == null || !context.mounted) return;
        await applyToLedger(context, (ledger) => ledger.renameCategory(category.id, name));
      case _Action.move:
        final target = await showDialog<_MoveTarget>(
          context: context,
          builder: (_) => _MoveDialog(tree: tree, category: category),
        );
        if (target == null || !context.mounted) return;
        await applyToLedger(
          context,
          (ledger) => ledger.moveCategory(category.id, parentId: target.parentId, nature: target.nature),
        );
      case _Action.up || _Action.down:
        final modification = context.read<LedgerCubit>().state.ledger.reorderCategory(
          category.id,
          action == _Action.up ? -1 : 1,
        );
        if (modification != null) await applyToLedger(context, (_) => modification);
      case _Action.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(switch (ledger.rulesOfCategory(category.year, category.id).length) {
              0 => l.categoryDeleteConfirm(category.name),
              final count => l.categoryDeleteWithRules(category.name, count),
            }),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        if (await applyToLedger(context, (ledger) => ledger.removeCategory(category.id)) && context.mounted) {
          showMessage(context, l.categoryDeleted);
        }
    }
  }
}

Future<String?> _askName(BuildContext context, String title, String initial) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, initial: initial),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('categoryName'),
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l.categoryName),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        TextButton(onPressed: () => Navigator.of(context).pop(_name.text), child: Text(l.save)),
      ],
    );
  }
}

class _GroupDialog extends StatefulWidget {
  const _GroupDialog();

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  final _name = TextEditingController();
  var _nature = CategoryNature.expense;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.categoriesNewGroup),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('categoryName'),
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(labelText: l.categoryName),
          ),
          const SizedBox(height: 16),
          SegmentedButton<CategoryNature>(
            segments: [
              for (final nature in CategoryNature.values)
                ButtonSegment(value: nature, label: Text(natureText(l, nature))),
            ],
            selected: {_nature},
            onSelectionChanged: (s) => setState(() => _nature = s.single),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        TextButton(onPressed: () => Navigator.of(context).pop((_name.text, _nature)), child: Text(l.save)),
      ],
    );
  }
}

class _MoveTarget {
  const _MoveTarget({this.parentId, this.nature});

  final String? parentId;
  final CategoryNature? nature;
}

class _MoveDialog extends StatelessWidget {
  const _MoveDialog({required this.tree, required this.category});

  /// The tree of the category's year; null when the year has only detached
  /// categories.
  final CategoryTree? tree;
  final Category category;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tree = this.tree;
    final excluded = tree == null || !tree.byId.containsKey(category.id)
        ? const <String>{}
        : tree.subtreeOf(category.id);
    return SimpleDialog(
      title: Text(l.categoryMoveTitle(category.name)),
      children: [
        for (final nature in CategoryNature.values)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_MoveTarget(nature: nature)),
            child: Text(l.categoryTopLevel(natureText(l, nature))),
          ),
        if (tree != null) const Divider(),
        for (final target in tree?.ordered ?? const <Category>[])
          if (!excluded.contains(target.id))
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(_MoveTarget(parentId: target.id)),
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: 16.0 * tree!.depthOf(target.id)),
                child: Text(target.name),
              ),
            ),
      ],
    );
  }
}
