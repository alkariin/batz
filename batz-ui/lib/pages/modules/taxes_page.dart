import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/modules/settings.dart';
import '../../domain/modules/taxes.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import 'module_category_tile.dart';

String taxName(AppLocalizations l, TaxKind tax) => switch (tax) {
  TaxKind.federalIncome => l.taxesFederalIncome,
  TaxKind.cantonalIncome => l.taxesCantonalIncome,
  TaxKind.communalIncome => l.taxesCommunalIncome,
  TaxKind.cantonalWealth => l.taxesCantonalWealth,
  TaxKind.communalWealth => l.taxesCommunalWealth,
};

String _rate(int value) => formatScaledPercent(value, 4);
String _percent(int value) => formatScaledPercent(value, 2);

/// Plus › Analyses › « Impôts » (step 6.3, decision H4 of phase 6): a fiscal
/// year, its five lines with their total rate and amount, the total and its
/// share of the salary, the marginal rate, the control against what the
/// economic view counts in the taxes category; the summary of every year.
class TaxesPage extends StatefulWidget {
  const TaxesPage({super.key});

  @override
  State<TaxesPage> createState() => _TaxesPageState();
}

class _TaxesPageState extends State<TaxesPage> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final current = context.read<AppServices>().today().year;
    final entered = ledger.taxYears;
    final years = {current - 1, current, ...entered, ...ledger.yearsWithTree}.toList()..sort();
    final year = _year ?? (entered.isEmpty ? current - 1 : entered.last);
    final result = ledger.taxYear(year);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.taxesTitle),
        actions: [
          if (result.record != null)
            IconButton(
              key: const Key('taxesDelete'),
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
                Text(l.taxesYear),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  key: const Key('taxesYear'),
                  value: year,
                  items: [for (final y in years.reversed) DropdownMenuItem(value: y, child: Text('$y'))],
                  onChanged: (y) => setState(() => _year = y),
                ),
              ],
            ),
          ),
          ModuleCategoryTile(module: ModuleKind.taxes, year: year),
          _TaxForm(key: ValueKey((year, result.record, ledger.modules.taxLines[year])), result: result),
          if (entered.isNotEmpty)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.taxesSummary, style: theme.textTheme.titleMedium),
                    for (final y in entered.reversed)
                      () {
                        final r = ledger.taxYear(y);
                        String percent(int? value) => value == null ? l.taxesNone : _percent(value);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '$y · ${l.taxesSummaryLine(formatAmount(r.total), percent(r.shareOfGross), percent(r.shareOfNet), percent(r.record?.marginalRate), r.paid == null ? l.taxesNone : formatAmount(r.paid!), r.gap == null ? l.taxesNone : formatAmount(r.gap!))}',
                            key: ValueKey('taxesSummary-$y'),
                          ),
                        );
                      }(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _delete(int year) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.taxesDeleteConfirm('$year')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await applyToLedger(context, (ledger) => ledger.deleteTaxYear(year)) && mounted) {
      showMessage(context, l.taxesDeleted);
    }
  }
}

class _LineControllers {
  _LineControllers(TaxLineResult line)
    : base = TextEditingController(text: line.tax.onWealth || line.base == null ? '' : formatAmount(line.base!)),
      rate = TextEditingController(text: line.baseRate == null ? '' : _plain(line.baseRate!, 4)),
      coefficient = TextEditingController(text: _plain(line.coefficient, 2));

  final TextEditingController base, rate, coefficient;

  /// [value] in 10^-[decimals] as typed: `6.5`, `155`.
  static String _plain(int value, int decimals) {
    final text = formatScaledPercent(value, decimals).replaceFirst(' %', '');
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }

  void dispose() {
    base.dispose();
    rate.dispose();
    coefficient.dispose();
  }
}

class _TaxForm extends StatefulWidget {
  const _TaxForm({super.key, required this.result});

  final TaxYearResult result;

  @override
  State<_TaxForm> createState() => _TaxFormState();
}

class _TaxFormState extends State<_TaxForm> {
  late final _wealth = TextEditingController(
    text: widget.result.record?.taxableWealth == null ? '' : formatAmount(widget.result.record!.taxableWealth!),
  );
  late final _marginal = TextEditingController(
    text: widget.result.record?.marginalRate == null
        ? ''
        : _LineControllers._plain(widget.result.record!.marginalRate!, 2),
  );
  late final _lines = {for (final line in widget.result.lines) line.tax: _LineControllers(line)};

  @override
  void dispose() {
    _wealth.dispose();
    _marginal.dispose();
    for (final c in _lines.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Null when empty; throws [FormatException] when invalid.
  static int? _read(TextEditingController c, int? Function(String) parse) {
    if (c.text.trim().isEmpty) return null;
    return parse(c.text) ?? (throw const FormatException());
  }

  static int? _amount(String text) {
    final cents = parseAmount(text);
    return cents == null || cents < 0 ? null : cents;
  }

  TaxYearDraft _draft() => TaxYearDraft(
    year: widget.result.year,
    taxableWealth: _read(_wealth, _amount),
    marginalRate: _read(_marginal, (t) => parseScaled(t, 2)),
    lines: {
      for (final MapEntry(key: tax, value: c) in _lines.entries)
        tax: TaxLineDraft(
          base: tax.onWealth ? null : _read(c.base, _amount),
          baseRate: _read(c.rate, (t) => parseScaled(t, 4)),
          coefficient: _read(c.coefficient, (t) => parseScaled(t, 2)) ?? fullCoefficient,
        ),
    },
  );

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final TaxYearDraft draft;
    try {
      draft = _draft();
    } on FormatException {
      showMessage(context, l.taxesInvalid);
      return;
    }
    if (await applyToLedger(context, (ledger) => ledger.saveTaxYear(draft)) && mounted) {
      showMessage(context, l.taxesSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = widget.result;
    TaxYearDraft? draft;
    try {
      draft = _draft();
    } on FormatException {
      draft = null;
    }
    // The amounts of what is typed, computed as the domain computes them.
    final amounts = <TaxKind, int?>{
      for (final tax in TaxKind.values)
        tax: () {
          final line = draft?.lines[tax];
          final base = tax.onWealth ? draft?.taxableWealth : line?.base;
          if (line == null || line.baseRate == null) return null;
          return base == null ? 0 : taxAmount(base, line.baseRate!, line.coefficient);
        }(),
    };
    final total = draft == null ? null : amounts.values.fold(0, (sum, a) => sum + (a ?? 0));
    final sheet = result.sheet;
    void changed(String _) => setState(() {});
    Widget field(String key, TextEditingController c, String label) => Expanded(
      child: TextField(
        key: ValueKey(key),
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: changed,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              field('taxesWealth', _wealth, l.taxesTaxableWealth),
              const SizedBox(width: 12),
              field('taxesMarginal', _marginal, l.taxesMarginalRate),
            ],
          ),
          for (final tax in TaxKind.values)
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(taxName(l, tax), style: theme.textTheme.titleSmall),
                    Row(
                      children: [
                        if (!tax.onWealth) ...[
                          field('taxesBase-${tax.name}', _lines[tax]!.base, l.taxesBase),
                          const SizedBox(width: 8),
                        ],
                        field('taxesRate-${tax.name}', _lines[tax]!.rate, l.taxesBaseRate),
                        const SizedBox(width: 8),
                        field('taxesCoefficient-${tax.name}', _lines[tax]!.coefficient, l.taxesCoefficient),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(() {
                      final line = draft?.lines[tax];
                      final amount = amounts[tax];
                      if (line?.baseRate == null || amount == null) return l.taxesLineIncomplete;
                      return l.taxesLineResult(
                        _rate(totalRate(line!.baseRate!, line.coefficient)),
                        formatAmount(amount),
                      );
                    }(), key: ValueKey('taxesLine-${tax.name}')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          _Figure(
            keyName: 'taxesTotal',
            label: l.taxesTotal,
            value: total == null ? l.taxesNone : formatAmount(total),
            strong: true,
          ),
          if (sheet == null)
            Text(l.taxesNoSheet('${result.year}'), style: theme.textTheme.bodySmall)
          else if (total != null) ...[
            _Figure(
              keyName: 'taxesShareOfGross',
              label: l.taxesShareOfGross,
              value: _percent(shareOf(total, sheet.gross)),
            ),
            if (sheet.net != 0)
              _Figure(keyName: 'taxesShareOfNet', label: l.taxesShareOfNet, value: _percent(shareOf(total, sheet.net))),
          ],
          const Divider(),
          Text(l.taxesControl, style: theme.textTheme.titleSmall),
          if (result.paid == null)
            Text(l.taxesNoControl('${result.year}'), key: const Key('taxesNoControl'))
          else ...[
            _Figure(keyName: 'taxesPaid', label: l.taxesPaid('${result.year}'), value: formatAmount(result.paid!)),
            if (total != null)
              _Figure(
                keyName: 'taxesGap',
                label: switch (total - result.paid!) {
                  > 0 => l.taxesLeftToPay,
                  < 0 => l.taxesPaidTooMuch,
                  _ => l.taxesSettled,
                },
                value: formatAmount((total - result.paid!).abs()),
              ),
            Text(l.taxesPaidHint('${result.year}'), style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          FilledButton(key: const Key('taxesSave'), onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.keyName, required this.label, required this.value, this.strong = false});

  final String keyName;
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong ? Theme.of(context).textTheme.titleMedium : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, key: ValueKey(keyName), style: style),
        ],
      ),
    );
  }
}
