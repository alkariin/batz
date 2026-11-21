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
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import '../refunds/refund_target_page.dart';
import 'rule_form_page.dart';
import 'validation_texts.dart';

/// What an imported line is classified as: the three choices of the
/// validation (decision H4 of phase 4).
enum _Mode { category, transfer, refund }

/// Classifies one imported line: a category of its year and a period, a
/// transfer with another account, or, for money that came in, a refund
/// attached to an expense; its description and note. Validating it writes
/// the classification (principle 4); for a proposed line it is the
/// correction of decision H4. « Créer une règle » starts from it.
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

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _description.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Starts from the stored classification of a validated line, or from the
  /// proposal of the rules.
  void _initialise(Ledger ledger, LedgerTransaction t) {
    _initialised = true;
    _description.text = t.description;
    _note.text = t.note;
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
    if (_categoryId == null) {
      showMessage(context, l.classifyChooseCategory);
      return null;
    }
    final start = DateField.read(_start) ?? t.date, end = DateField.read(_end) ?? start;
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
  /// that the rule classifies at least this line (step 4.0).
  Future<void> _createRule(LedgerTransaction t) async {
    final keyword = suggestedKeyword(_description.text, t.rawText ?? '');
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => RuleFormPage(
          year: t.date.year,
          initial: RuleDraft(
            year: t.date.year,
            keywords: [?keyword],
            // Mapping rules never attach a refund (H4).
            targetCategoryId: _mode == _Mode.category ? _categoryId : null,
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
    final categories = ledger.trees[t.date.year]?.assignable ?? const [];
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
                rules.map((r) => '« ${keywordsText(r)} » → ${ruleTargetText(l, ledger, r)}').join(' ; '),
              ),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (outcome case UnusableRule(:final rule)) ...[
            const SizedBox(height: 8),
            Text(l.validationUnusable(keywordsText(rule)), style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (outcome case Proposed(:final rule)) ...[
            const SizedBox(height: 8),
            Text(l.validationRule(keywordsText(rule)), style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          SegmentedButton<_Mode>(
            key: const Key('classifyMode'),
            segments: [
              ButtonSegment(value: _Mode.category, label: Text(l.classifyCategory)),
              ButtonSegment(value: _Mode.transfer, label: Text(l.classifyTransfer)),
              // Only money that came in refunds an expense (H4).
              if (t.amount > 0) ButtonSegment(value: _Mode.refund, label: Text(l.classifyRefund)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          if (_mode == _Mode.refund) ...[
            Text(l.refundExpense, style: theme.textTheme.labelMedium),
            if (ledger.linesById[_expenseLineId] case final expense?)
              expenseTile(context, ledger, expense.transaction, key: const Key('classifyExpense'))
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
        ],
      ),
    );
  }
}
