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
import '../refunds/refund_target_page.dart';
import 'split_editor.dart';

/// Records an expense or an income, or modifies [transaction]: in one
/// category, or split between several, each line with its amount and
/// period.
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

  /// The expense line this entry refunds, when attached.
  late String? _refundedLineId = _existing?.line?.refundedLineId;
  late bool _refund = _refundedLineId != null;

  late bool _customPeriod =
      _existing?.line != null &&
      (_existing!.line!.periodStart != _existing.date || _existing.line!.periodEnd != _existing.date);

  /// The lines of a split entry, the main one first; empty while the entry
  /// has one category.
  late final List<SplitLineEdit> _splitLines = _existing != null && _existing.isSplit
      ? SplitLineEdit.of(_existing)
      : [];

  bool get _split => _splitLines.isNotEmpty;

  /// The line an entry in one category keeps: the one left when a split
  /// entry is brought back to one line.
  late String? _mainLineId = _existing?.line?.id;

  /// The year whose categories are offered: that of the date typed last.
  late int _year = _initialDate.year;

  /// The payment date read last, that split lines over it follow.
  late CalendarDate _paymentDate = _initialDate;

  CalendarDate get _initialDate => _existing?.date ?? CalendarDate.today();

  @override
  void dispose() {
    for (final c in [_amount, _date, _description, _note, _periodStart, _periodEnd]) {
      c.dispose();
    }
    for (final line in _splitLines) {
      line.dispose();
    }
    super.dispose();
  }

  /// Splits the entry: its category and period become the first line, a
  /// second line starts over the same period.
  void _startSplit() {
    final date = DateField.read(_date) ?? _paymentDate;
    final start = _customPeriod ? DateField.read(_periodStart) ?? date : date;
    final end = _customPeriod ? DateField.read(_periodEnd) ?? start : date;
    final mainId = _mainLineId ??= newId();
    setState(() {
      _splitLines.addAll([
        SplitLineEdit(id: mainId, categoryId: _categoryId, start: start, end: end),
        SplitLineEdit(id: newId(), start: start, end: end),
      ]);
    });
  }

  /// A new line, over the period of the first one.
  void _addLine() {
    final first = _splitLines.first;
    final date = DateField.read(_date) ?? _paymentDate;
    setState(() {
      _splitLines.add(
        SplitLineEdit(id: newId(), start: DateField.read(first.start) ?? date, end: DateField.read(first.end) ?? date),
      );
    });
  }

  /// Removes the line [index]; with one line left, the entry is in one
  /// category again, that line's.
  void _removeLine(int index) {
    final removed = [_splitLines.removeAt(index)];
    if (_splitLines.length == 1) {
      final last = _splitLines.removeLast();
      removed.add(last);
      final date = DateField.read(_date) ?? _paymentDate;
      final start = DateField.read(last.start) ?? date, end = DateField.read(last.end) ?? start;
      _categoryId = last.categoryId;
      _mainLineId = last.id;
      _customPeriod = start != date || end != date;
      _periodStart.text = DateField.text(start);
      _periodEnd.text = DateField.text(end);
    }
    setState(() {});
    // Their fields leave the screen with this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final line in removed) {
        line.dispose();
      }
    });
  }

  /// Accounts that accept a manual expense or income.
  List<Account> _accounts(Ledger ledger) => [
    for (final a in ledger.sortedAccounts)
      if ((!a.archived || a.id == _existing?.accountId) && !a.isDetailed && a.type != AccountType.debts) a,
  ];

  /// A new payment date: split lines over the previous one follow it. A new
  /// payment year: each category becomes the one of the same name in that
  /// year's tree, if any.
  void _dateChanged(Ledger ledger) {
    final date = DateField.read(_date);
    if (date != null && date != _paymentDate) {
      for (final line in _splitLines) {
        if (DateField.read(line.start) == _paymentDate && DateField.read(line.end) == _paymentDate) {
          line.start.text = DateField.text(date);
          line.end.text = DateField.text(date);
        }
      }
      _paymentDate = date;
    }
    if (date == null || date.year == _year) {
      setState(() {});
      return;
    }
    final before = ledger.treeOrPreview(_year), after = ledger.treeOrPreview(date.year);
    String? sameName(String? id) {
      final previous = ledger.categories[id] ?? before.byId[id];
      final match = previous == null ? null : after.named(previous.name);
      return match != null && after.canHoldTransactions(match.id) ? match.id : null;
    }

    setState(() {
      _year = date.year;
      _categoryId = sameName(_categoryId);
      for (final line in _splitLines) {
        line.categoryId = sameName(line.categoryId);
      }
    });
  }

  Direction _effectiveDirection(CategoryTree tree) {
    if (_direction != null) return _direction!;
    final category = tree.byId[_split ? _splitLines.first.categoryId : _categoryId];
    return category == null ? Direction.outflow : defaultDirection(tree.natureOf(category.id));
  }

  Future<void> _save(Ledger ledger) async {
    final l = AppLocalizations.of(context);
    final cents = parseAmount(_amount.text);
    final date = DateField.read(_date);
    final direction = date == null ? Direction.outflow : _effectiveDirection(ledger.treeOrPreview(date.year));
    // Only money that comes in refunds an expense; its period is then its
    // date, its category that of the expense.
    final refund = _refund && direction == Direction.inflow;
    final split = _split && !refund;
    final start = _customPeriod && !refund && !split ? DateField.read(_periodStart) : null;
    final end = _customPeriod && !refund && !split ? DateField.read(_periodEnd) : null;
    final String? problem;
    if (cents == null || cents <= 0 || _amount.text.trim().startsWith('-')) {
      problem = l.errorAmountInvalid;
    } else if (date == null || (_customPeriod && !refund && !split && (start == null || end == null))) {
      problem = l.errorDateInvalid;
    } else if (_accountId == null) {
      problem = l.errorAccountMissing;
    } else if (refund && _refundedLineId == null) {
      problem = l.refundExpenseMissing;
    } else if (!refund && !split && _categoryId == null) {
      problem = l.errorCategoryMissing;
    } else {
      problem = null;
    }
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    var lines = const <LineDraft>[];
    if (split) {
      final drafts = splitDrafts(context, _splitLines, cents!);
      if (drafts == null) return;
      lines = drafts;
    } else if (!refund && (_existing?.isSplit ?? false)) {
      // A split entry brought back to one category keeps the line left.
      lines = [
        LineDraft(id: _mainLineId!, categoryId: _categoryId!, cents: cents!, periodStart: start, periodEnd: end),
      ];
    }
    final draft = EntryDraft(
      accountId: _accountId!,
      date: date!,
      cents: cents!,
      direction: direction,
      categoryId: _categoryId,
      description: _description.text,
      note: _note.text,
      periodStart: start,
      periodEnd: end,
      refundedLineId: refund ? _refundedLineId : null,
      lines: lines,
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
            // The first line of a split takes the rest.
            onChanged: (_) => setState(() {}),
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
          if (direction == Direction.inflow) ...[
            SwitchListTile(
              key: const Key('entryRefund'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.entryRefund),
              subtitle: Text(l.refundHint),
              value: _refund,
              onChanged: (value) => setState(() => _refund = value),
            ),
            if (_refund) ...[
              if (ledger.linesById[_refundedLineId] case final expense?)
                expenseTile(context, ledger, expense, key: const Key('entryExpense'))
              else
                ListTile(contentPadding: EdgeInsets.zero, title: Text(l.refundExpenseMissing)),
              OutlinedButton.icon(
                key: const Key('entryPickExpense'),
                icon: const Icon(Icons.search),
                label: Text(l.refundPick),
                onPressed: () async {
                  final lineId = await Navigator.of(context).push(
                    MaterialPageRoute<String>(builder: (_) => RefundTargetPage(excludeTransactionId: _existing?.id)),
                  );
                  if (lineId != null && mounted) setState(() => _refundedLineId = lineId);
                },
              ),
            ],
          ],
          const SizedBox(height: 12),
          if (!(_refund && direction == Direction.inflow) && _split)
            SplitEditor(
              lines: _splitLines,
              tree: tree,
              totalCents: parseAmount(_amount.text),
              onChanged: () => setState(() {}),
              onAdd: _addLine,
              onRemove: _removeLine,
            )
          else if (!(_refund && direction == Direction.inflow)) ...[
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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('split'),
                icon: const Icon(Icons.call_split),
                label: Text(l.splitAction),
                onPressed: categories.isEmpty ? null : _startSplit,
              ),
            ),
          ],
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
          if (!(_refund && direction == Direction.inflow) && !_split)
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
          if (_customPeriod && !(_refund && direction == Direction.inflow) && !_split) ...[
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
