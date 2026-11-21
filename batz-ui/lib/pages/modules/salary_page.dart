import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ids.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/modules/salary.dart';
import '../../domain/modules/settings.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import 'module_category_tile.dart';

/// Plus › Analyses › « Fiche salaire »: the sheet of a year, gross,
/// deductions and net, with the gap computed as they are typed, and the
/// category of the salary.
class SalaryPage extends StatefulWidget {
  const SalaryPage({super.key, this.initialYear});

  final int? initialYear;

  @override
  State<SalaryPage> createState() => _SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final current = context.read<AppServices>().today().year;
    final years = {current, ...ledger.yearsWithTree, ...ledger.modules.salarySheets.keys}.toList()..sort();
    final year = _year ?? widget.initialYear ?? current;
    final sheet = ledger.salarySheet(year);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.salaryTitle),
        actions: [
          if (sheet != null)
            IconButton(
              key: const Key('salaryDelete'),
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(year),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(l.salaryYear),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  key: const Key('salaryYear'),
                  value: year,
                  items: [for (final y in years.reversed) DropdownMenuItem(value: y, child: Text('$y'))],
                  onChanged: (y) => setState(() => _year = y),
                ),
              ],
            ),
          ),
          ModuleCategoryTile(module: ModuleKind.salary, year: year),
          // A new form for each year and each version of the sheet.
          _SheetForm(key: ValueKey((year, sheet)), year: year, sheet: sheet, ledger: ledger),
        ],
      ),
    );
  }

  Future<void> _delete(int year) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.salaryDeleteConfirm('$year')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await applyToLedger(context, (ledger) => ledger.deleteSalarySheet(year)) && mounted) {
      showMessage(context, l.salaryDeleted);
    }
  }
}

class _Row {
  _Row({this.id, String label = '', String amount = ''})
    : label = TextEditingController(text: label),
      amount = TextEditingController(text: amount);

  final String? id;
  final TextEditingController label;
  final TextEditingController amount;

  void dispose() {
    label.dispose();
    amount.dispose();
  }
}

class _SheetForm extends StatefulWidget {
  const _SheetForm({super.key, required this.year, required this.sheet, required this.ledger});

  final int year;
  final SalarySheet? sheet;
  final Ledger ledger;

  @override
  State<_SheetForm> createState() => _SheetFormState();
}

class _SheetFormState extends State<_SheetForm> {
  late final _gross = TextEditingController(text: _text(widget.sheet?.gross));
  late final _net = TextEditingController(text: _text(widget.sheet?.net));
  late final List<_Row> _rows = widget.sheet == null
      ? [for (final label in widget.ledger.proposedDeductionLabels(widget.year)) _Row(label: label)]
      : [for (final d in widget.sheet!.deductions) _Row(id: d.id, label: d.label, amount: formatAmount(d.amount))];

  static String _text(int? cents) => cents == null ? '' : formatAmount(cents);

  @override
  void dispose() {
    _gross.dispose();
    _net.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  /// The amount typed, null when empty or invalid.
  static int? _amount(TextEditingController c) => parseAmount(c.text);

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final gross = _amount(_gross), net = _amount(_net);
    final amounts = [for (final row in _rows) _amount(row.amount)];
    if (gross == null || net == null || amounts.contains(null)) {
      showMessage(context, l.salaryInvalidAmount);
      return;
    }
    final draft = SalarySheetDraft(
      year: widget.year,
      gross: gross,
      net: net,
      deductions: [
        for (final (i, row) in _rows.indexed) DeductionDraft(id: row.id, label: row.label.text, amount: amounts[i]!),
      ],
    );
    if (await applyToLedger(context, (ledger) => ledger.saveSalarySheet(draft, newId: newId)) && mounted) {
      showMessage(context, l.salarySaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final gross = _amount(_gross), net = _amount(_net);
    final deductions = _rows.fold(0, (sum, row) => sum + (_amount(row.amount) ?? 0));
    final gap = gross == null || net == null ? null : gross - deductions - net;
    void changed(String _) => setState(() {});
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.sheet == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l.salaryNew('${widget.year}'), style: theme.textTheme.bodySmall),
            ),
          TextField(
            key: const Key('salaryGross'),
            controller: _gross,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.salaryGross),
            onChanged: changed,
          ),
          const SizedBox(height: 16),
          Text(l.salaryDeductions, style: theme.textTheme.titleSmall),
          for (final (i, row) in _rows.indexed)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: ValueKey('salaryDeductionLabel-$i'),
                    controller: row.label,
                    decoration: InputDecoration(labelText: l.salaryDeductionLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: ValueKey('salaryDeductionAmount-$i'),
                    controller: row.amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l.salaryDeductionAmount),
                    onChanged: changed,
                  ),
                ),
                IconButton(
                  key: ValueKey('salaryDeductionRemove-$i'),
                  tooltip: l.salaryDeductionRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() => _rows.removeAt(i).dispose()),
                ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('salaryDeductionAdd'),
              onPressed: () => setState(() => _rows.add(_Row())),
              icon: const Icon(Icons.add),
              label: Text(l.salaryDeductionAdd),
            ),
          ),
          Text(l.salaryDeductionsTotal(formatAmount(deductions)), key: const Key('salaryDeductionsTotal')),
          const SizedBox(height: 8),
          TextField(
            key: const Key('salaryNet'),
            controller: _net,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.salaryNet),
            onChanged: changed,
          ),
          const SizedBox(height: 8),
          if (gap != null)
            gap == 0
                ? Text(l.salaryBalanced, key: const Key('salaryBalanced'))
                : Text(
                    l.salaryGap(formatAmount(gap)),
                    key: const Key('salaryGap'),
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error),
                  ),
          Text(l.salaryTwoEmployers, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton(key: const Key('salarySave'), onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}
