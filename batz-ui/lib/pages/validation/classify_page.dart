import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/date_field.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/proposal.dart';
import '../../domain/ledger/refund.dart';
import '../../domain/ledger/rule.dart';
import '../../domain/ledger/transaction.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../debts/debt_form_page.dart';
import '../debts/debt_links.dart';
import '../../domain/ledger/debt.dart';
import '../../domain/ids.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import '../refunds/refund_target_page.dart';
import '../transactions/split_editor.dart';
import 'rule_form_page.dart';
import 'validation_texts.dart';

/// What an imported line is classified as: the three choices of the
/// validation.
enum _Mode { category, transfer, refund }

/// Classifies one imported line: a category of its year and a period (or
/// several, each with its amount and period, when it is split), a transfer
/// with another account, or, for money that came in, a refund attached to
/// an expense; its description and note. Validating it writes the
/// classification; for a proposed line it is the correction of the proposal. «
/// Créer une règle » starts from it, and so does a debt it gives rise to.
class ClassifyPage extends StatefulWidget {
  const ClassifyPage({super.key, required this.transactionId});

  final String transactionId;

  @override
  State<ClassifyPage> createState() => _ClassifyPageState();
}

class _ClassifyPageState extends State<ClassifyPage> {
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _description = TextEditingController();
  final _note = TextEditingController();
  var _mode = _Mode.category;
  String? _categoryId;
  String? _accountId;
  String? _expenseLineId;
  var _initialised = false;

  /// The lines of a split classification, the main one first; empty while
  /// the line goes to one category.
  final _splitLines = <SplitLineEdit>[];

  bool get _split => _splitLines.isNotEmpty;

  /// The line a classification in one category keeps: the imported line's
  /// own, or the one left when a split line is brought back to one.
  late String _mainLineId;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _description.dispose();
    _note.dispose();
    for (final line in _splitLines) {
      line.dispose();
    }
    super.dispose();
  }

  /// Splits the line: its category and period become the first line, a
  /// second line starts over the same period.
  void _startSplit(LedgerTransaction t) {
    final start = DateField.read(_start) ?? t.date, end = DateField.read(_end) ?? start;
    setState(() {
      _splitLines.addAll([
        SplitLineEdit(id: _mainLineId, categoryId: _categoryId, start: start, end: end),
        SplitLineEdit(id: newId(), start: start, end: end),
      ]);
    });
  }

  void _addLine(LedgerTransaction t) {
    final first = _splitLines.first;
    setState(() {
      _splitLines.add(
        SplitLineEdit(
          id: newId(),
          start: DateField.read(first.start) ?? t.date,
          end: DateField.read(first.end) ?? t.date,
        ),
      );
    });
  }

  /// Removes the line [index]; with one line left, the line goes to one
  /// category again, that line's.
  void _removeLine(int index) {
    final removed = [_splitLines.removeAt(index)];
    if (_splitLines.length == 1) {
      final last = _splitLines.removeLast();
      removed.add(last);
      _categoryId = last.categoryId;
      _mainLineId = last.id;
      _start.text = last.start.text;
      _end.text = last.end.text;
    }
    setState(() {});
    // Their fields leave the screen with this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final line in removed) {
        line.dispose();
      }
    });
  }

  /// Starts from the stored classification of a validated line, or from the
  /// proposal of the rules.
  void _initialise(Ledger ledger, LedgerTransaction t) {
    _initialised = true;
    _description.text = t.description;
    _note.text = t.note;
    _mainLineId = t.line?.id ?? Ledger.fallbackLineId(t.id);
    if (t.isValidated && !t.isTransfer && t.isSplit) _splitLines.addAll(SplitLineEdit.of(t));
    final Classification? current = t.isValidated
        ? (t.isTransfer
              ? Classification.transfer(t.counterpartAccountId!)
              : t.line == null
              ? null
              : Classification.category(
                  t.line!.categoryId ?? '',
                  periodStart: t.line!.periodStart,
                  periodEnd: t.line!.periodEnd,
                ))
        : ledger.proposalOf(t);
    _mode = current?.isTransfer ?? false ? _Mode.transfer : _Mode.category;
    if (t.isValidated && t.line?.refundedLineId != null) {
      _mode = _Mode.refund;
      _expenseLineId = t.line!.refundedLineId;
    }
    _categoryId = current?.categoryId;
    _accountId = current?.counterpartAccountId;
    _start.text = DateField.text(current?.periodStart ?? t.date);
    _end.text = DateField.text(current?.periodEnd ?? t.date);
  }

  Classification? _classification(AppLocalizations l, LedgerTransaction t) {
    if (_mode == _Mode.transfer) {
      if (_accountId == null) {
        showMessage(context, l.classifyChooseAccount);
        return null;
      }
      return Classification.transfer(_accountId!);
    }
    if (_split) {
      final lines = splitDrafts(context, _splitLines, t.amount.abs());
      return lines == null ? null : Classification.split(lines);
    }
    if (_categoryId == null) {
      showMessage(context, l.classifyChooseCategory);
      return null;
    }
    final start = DateField.read(_start) ?? t.date, end = DateField.read(_end) ?? start;
    // A split line brought back to one category keeps the line left.
    if (t.isSplit) {
      return Classification.split([
        LineDraft(id: _mainLineId, categoryId: _categoryId!, cents: t.amount.abs(), periodStart: start, periodEnd: end),
      ]);
    }
    return Classification.category(_categoryId!, periodStart: start, periodEnd: end);
  }

  Future<void> _validate(LedgerTransaction t) async {
    final l = AppLocalizations.of(context);
    if (_mode == _Mode.refund) {
      final expense = _expenseLineId;
      if (expense == null) {
        showMessage(context, l.refundExpenseMissing);
        return;
      }
      final saved = await applyToLedger(
        context,
        (ledger) => ledger.validateAsRefund(t.id, expense, description: _description.text, note: _note.text),
      );
      if (saved && mounted) {
        showMessage(context, l.refundAttached);
        Navigator.of(context).pop(true);
      }
      return;
    }
    final classification = _classification(l, t);
    if (classification == null) return;
    final saved = await applyToLedger(
      context,
      (ledger) => ledger.validateLine(t.id, classification, description: _description.text, note: _note.text),
    );
    if (saved && mounted) {
      showMessage(context, l.classifyValidated);
      Navigator.of(context).pop(true);
    }
  }

  /// The form starts with a keyword found in the bank text of the line, so
  /// that the rule classifies at least this line.
  Future<void> _createRule(LedgerTransaction t) async {
    final keyword = suggestedKeyword(_description.text, t.rawText ?? '');
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => RuleFormPage(
          year: t.date.year,
          chooseTarget: true,
          initial: RuleDraft(
            year: t.date.year,
            lines: [?keyword],
            // Mapping rules never attach a refund.
            targetCategoryId: _mode == _Mode.category ? (_split ? _splitLines.first.categoryId : _categoryId) : null,
            targetAccountId: _mode == _Mode.transfer ? _accountId : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final t = ledger.transactions[widget.transactionId];
    if (t == null) return Scaffold(appBar: AppBar(title: Text(l.classifyTitle)));
    if (!_initialised) _initialise(ledger, t);
    final theme = Theme.of(context);
    final tree = ledger.trees[t.date.year];
    final categories = tree?.assignable ?? const [];
    final accounts = [
      for (final a in ledger.sortedAccounts)
        if (!a.isDetailed && a.id != t.accountId && (!a.archived || a.id == t.counterpartAccountId)) a,
    ];
    final outcome = ledger.proposals[t.id];
    return Scaffold(
      appBar: AppBar(title: Text(l.classifyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(formatDate(t.date.toDateTime())),
            trailing: Text(formatAmount(t.amount), style: theme.textTheme.titleLarge),
          ),
          Text(l.fieldRawText, style: theme.textTheme.labelMedium),
          SelectableText(t.rawText ?? '', key: const Key('classifyRawText')),
          if (outcome case Conflict(:final rules)) ...[
            const SizedBox(height: 8),
            Text(
              l.validationConflict(
                rules.map((r) => '« ${keywordsText(l, r)} » → ${ruleTargetText(l, ledger, r)}').join(' ; '),
              ),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (outcome case UnusableRule(:final rule)) ...[
            const SizedBox(height: 8),
            Text(l.validationUnusable(keywordsText(l, rule)), style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (outcome case Proposed(:final rule)) ...[
            const SizedBox(height: 8),
            Text(l.validationRule(keywordsText(l, rule)), style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          SegmentedButton<_Mode>(
            key: const Key('classifyMode'),
            segments: [
              ButtonSegment(value: _Mode.category, label: Text(l.classifyCategory)),
              ButtonSegment(value: _Mode.transfer, label: Text(l.classifyTransfer)),
              // Only money that came in refunds an expense.
              if (t.amount > 0) ButtonSegment(value: _Mode.refund, label: Text(l.classifyRefund)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          if (_mode == _Mode.refund) ...[
            Text(l.refundExpense, style: theme.textTheme.labelMedium),
            if (ledger.linesById[_expenseLineId] case final expense?)
              expenseTile(context, ledger, expense, key: const Key('classifyExpense'))
            else
              ListTile(contentPadding: EdgeInsets.zero, title: Text(l.refundExpenseMissing)),
            OutlinedButton.icon(
              key: const Key('classifyPickExpense'),
              icon: const Icon(Icons.search),
              label: Text(l.refundPick),
              onPressed: () async {
                final lineId = await Navigator.of(context)
                    .push(MaterialPageRoute<String>(builder: (_) => RefundTargetPage(excludeTransactionId: t.id)));
                if (lineId != null && mounted) setState(() => _expenseLineId = lineId);
              },
            ),
            const SizedBox(height: 8),
            Text(l.refundHint, style: theme.textTheme.bodySmall),
          ] else if (_mode == _Mode.category && _split) ...[
            SplitEditor(
              lines: _splitLines,
              tree: tree!,
              totalCents: t.amount.abs(),
              onChanged: () => setState(() {}),
              onAdd: () => _addLine(t),
              onRemove: _removeLine,
            ),
          ] else if (_mode == _Mode.category) ...[
            DropdownButtonFormField<String>(
              key: const Key('classifyCategory'),
              initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.classifyCategory),
              items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (id) => setState(() => _categoryId = id),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DateField(controller: _start, label: l.periodStart, fieldKey: const Key('classifyStart')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DateField(controller: _end, label: l.periodEnd, fieldKey: const Key('classifyEnd')),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('classifySplit'),
                icon: const Icon(Icons.call_split),
                label: Text(l.splitAction),
                onPressed: categories.isEmpty ? null : () => _startSplit(t),
              ),
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              key: const Key('classifyAccount'),
              initialValue: accounts.any((a) => a.id == _accountId) ? _accountId : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.classifyCounterpart,
                helperText: t.amount < 0 ? l.classifyTransferOut : l.classifyTransferIn,
              ),
              items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
              onChanged: (id) => setState(() => _accountId = id),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const Key('classifyDescription'),
            controller: _description,
            decoration: InputDecoration(labelText: l.fieldDescription),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('classifyNote'),
            controller: _note,
            decoration: InputDecoration(labelText: l.fieldNote),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('classifyValidate'),
            onPressed: () => _validate(t),
            child: Text(l.classifyValidate),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('classifyCreateRule'),
            icon: const Icon(Icons.rule),
            label: Text(l.classifyCreateRule),
            onPressed: () => _createRule(t),
          ),
          ..._debts(context, ledger, t),
        ],
      ),
    );
  }

  /// The debts of the line: those it gave rise to, which can be created
  /// here before it is validated, and those it repaid.
  List<Widget> _debts(BuildContext context, Ledger ledger, LedgerTransaction t) {
    final l = AppLocalizations.of(context);
    final from = ledger.debtsFrom(t.id), repaid = ledger.debtsRepaidBy(t.id);
    final repayable = ledger.debtsRepayableBy(t);
    // A transfer gives rise to no debt.
    final canCreate = _mode != _Mode.transfer;
    if (!canCreate && from.isEmpty && repaid.isEmpty && repayable.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      const Divider(),
      Text(l.debtsTitle, style: Theme.of(context).textTheme.titleMedium),
      for (final debt in from) debtTile(context, debt, relation: l.debtFromThis, contentPadding: EdgeInsets.zero),
      for (final debt in repaid) debtTile(context, debt, relation: l.debtRepaidByThis, contentPadding: EdgeInsets.zero),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (canCreate)
            OutlinedButton.icon(
              key: const Key('classifyCreateDebt'),
              icon: const Icon(Icons.add),
              label: Text(l.debtCreateFromTransaction),
              // The debt starts from the description typed so far; the line
              // stays to validate until it is.
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DebtFormPage(source: t, description: _description.text),
                ),
              ),
            ),
          // A line that repays a debt: once linked, a refund of the expense
          // the debt came from is validated with it; otherwise it is
          // classified here as usual.
          if (repayable.isNotEmpty)
            OutlinedButton.icon(
              key: const Key('classifyRepayDebt'),
              icon: const Icon(Icons.done_all),
              label: Text(l.debtRepayWithTransaction),
              onPressed: () async {
                final repaid = await repayDebtWith(context, t);
                if (!repaid || !context.mounted) return;
                if (context.read<LedgerCubit>().state.ledger.transactions[t.id]?.isValidated ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
            ),
        ],
      ),
    ];
  }
}
