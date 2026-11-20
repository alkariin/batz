import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/date_field.dart';
import '../../domain/calendar_date.dart';
import '../../domain/ids.dart';
import '../../domain/ledger/account.dart';
import '../../domain/ledger/category.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/transaction.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';

/// Records an expense or an income, or modifies [transaction].
class EntryFormPage extends StatefulWidget {
  const EntryFormPage({super.key, this.transaction});

  final LedgerTransaction? transaction;

  @override
  State<EntryFormPage> createState() => _EntryFormPageState();
}

class _EntryFormPageState extends State<EntryFormPage> {
  late final LedgerTransaction? _existing = widget.transaction;
  late final _amount = TextEditingController(text: _existing == null ? '' : formatAmount(_existing.amount.abs()));
  late final _date = TextEditingController(text: DateField.text(_existing?.date ?? CalendarDate.today()));
  late final _description = TextEditingController(text: _existing?.description);
  late final _note = TextEditingController(text: _existing?.note);
  late final _periodStart = TextEditingController(text: DateField.text(_existing?.line?.periodStart ?? _initialDate));
  late final _periodEnd = TextEditingController(text: DateField.text(_existing?.line?.periodEnd ?? _initialDate));

  late String? _accountId = _existing?.accountId;
  late String? _categoryId = _existing?.line?.categoryId;
  late Direction? _direction = _existing == null ? null : (_existing.amount < 0 ? Direction.outflow : Direction.inflow);
  late bool _customPeriod =
      _existing?.line != null &&
      (_existing!.line!.periodStart != _existing.date || _existing.line!.periodEnd != _existing.date);

  /// The year whose categories are offered: that of the date typed last.
  late int _year = _initialDate.year;

  CalendarDate get _initialDate => _existing?.date ?? CalendarDate.today();

  @override
  void dispose() {
    for (final c in [_amount, _date, _description, _note, _periodStart, _periodEnd]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Accounts that accept a manual expense or income.
  List<Account> _accounts(Ledger ledger) => [
    for (final a in ledger.sortedAccounts)
      if ((!a.archived || a.id == _existing?.accountId) && !a.isDetailed && a.type != AccountType.debts) a,
  ];

  /// A new payment year: the category becomes the one of the same name in
  /// that year's tree, if any (specification, 4.1).
  void _dateChanged(Ledger ledger) {
    final date = DateField.read(_date);
    if (date == null || date.year == _year) {
      setState(() {});
      return;
    }
    final previous = ledger.categories[_categoryId] ?? ledger.treeOrPreview(_year).byId[_categoryId];
    setState(() {
      _year = date.year;
      final match = previous == null ? null : ledger.treeOrPreview(_year).named(previous.name);
      _categoryId = match != null && ledger.treeOrPreview(_year).canHoldTransactions(match.id) ? match.id : null;
    });
  }

  Direction _effectiveDirection(CategoryTree tree) {
    if (_direction != null) return _direction!;
    final category = tree.byId[_categoryId];
    return category == null ? Direction.outflow : defaultDirection(tree.natureOf(category.id));
  }

  Future<void> _save(Ledger ledger) async {
    final l = AppLocalizations.of(context);
    final cents = parseAmount(_amount.text);
    final date = DateField.read(_date);
    final start = _customPeriod ? DateField.read(_periodStart) : null;
    final end = _customPeriod ? DateField.read(_periodEnd) : null;
    final String? problem;
    if (cents == null || cents <= 0 || _amount.text.trim().startsWith('-')) {
      problem = l.errorAmountInvalid;
    } else if (date == null || (_customPeriod && (start == null || end == null))) {
      problem = l.errorDateInvalid;
    } else if (_accountId == null) {
      problem = l.errorAccountMissing;
    } else if (_categoryId == null) {
      problem = l.errorCategoryMissing;
    } else {
      problem = null;
    }
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    final draft = EntryDraft(
      accountId: _accountId!,
      date: date!,
      cents: cents!,
      direction: _effectiveDirection(ledger.treeOrPreview(date.year)),
      categoryId: _categoryId!,
      description: _description.text,
      note: _note.text,
      periodStart: start,
      periodEnd: end,
    );
    final existing = _existing;
    final saved = await applyToLedger(
      context,
      (ledger) =>
          existing == null ? ledger.recordEntry(newId(), newId(), draft) : ledger.updateEntry(existing.id, draft),
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final accounts = _accounts(ledger);
    if (_accountId == null && accounts.length == 1) _accountId = accounts.single.id;
    final tree = ledger.treeOrPreview(_year);
    final categories = tree.assignable;
    final categoryId = categories.any((c) => c.id == _categoryId) ? _categoryId : null;
    final direction = _effectiveDirection(tree);

    return Scaffold(
      appBar: AppBar(title: Text(_existing == null ? l.entryNewTitle : l.entryEditTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (accounts.isEmpty) _Notice(l.entryNoAccount),
          if (categories.isEmpty) _Notice(l.entryNoCategory(_year)),
          TextField(
            key: const Key('amount'),
            controller: _amount,
            autofocus: _existing == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.fieldAmount, suffixText: 'CHF'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<Direction>(
            key: const Key('direction'),
            segments: [
              ButtonSegment(
                value: Direction.outflow,
                label: Text(l.directionOutflow),
                icon: const Icon(Icons.south_east),
              ),
              ButtonSegment(
                value: Direction.inflow,
                label: Text(l.directionInflow),
                icon: const Icon(Icons.north_west),
              ),
            ],
            selected: {direction},
            onSelectionChanged: (s) => setState(() => _direction = s.single),
          ),
          const SizedBox(height: 12),
          DateField(
            fieldKey: const Key('date'),
            controller: _date,
            label: l.fieldDate,
            onChanged: () => _dateChanged(ledger),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('account-${accounts.length}'),
            initialValue: accounts.any((a) => a.id == _accountId) ? _accountId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.fieldAccount),
            items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
            onChanged: (id) => setState(() => _accountId = id),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('category-$_year-$categoryId'),
            initialValue: categoryId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.fieldCategory),
            items: [
              for (final c in categories)
                DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.name} · ${natureText(l, tree.natureOf(c.id))}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('description'),
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.fieldDescription),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('note'),
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            maxLines: null,
            decoration: InputDecoration(labelText: l.fieldNote),
          ),
          SwitchListTile(
            key: const Key('customPeriod'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.periodCustom),
            subtitle: Text(l.periodCustomHint),
            value: _customPeriod,
            onChanged: (value) => setState(() {
              _customPeriod = value;
              if (value) {
                // Starts from the payment date typed so far.
                final date = DateField.read(_date);
                if (date != null && _existing == null) {
                  _periodStart.text = DateField.text(date);
                  _periodEnd.text = DateField.text(date);
                }
              }
            }),
          ),
          if (_customPeriod) ...[
            DateField(fieldKey: const Key('periodStart'), controller: _periodStart, label: l.periodStart),
            const SizedBox(height: 12),
            DateField(fieldKey: const Key('periodEnd'), controller: _periodEnd, label: l.periodEnd),
          ],
          const SizedBox(height: 24),
          FilledButton(key: const Key('save'), onPressed: () => _save(ledger), child: Text(l.save)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: TextStyle(color: colors.onSecondaryContainer)),
      ),
    );
  }
}
