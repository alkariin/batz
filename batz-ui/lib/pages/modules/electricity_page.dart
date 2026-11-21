import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/date_field.dart';
import '../../domain/modules/electricity.dart';
import '../../domain/modules/settings.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import '../transactions/transaction_texts.dart';
import 'module_category_tile.dart';

String _kwh(int wh) => formatDecimal(wh, 3, trim: true);

/// Plus › Analyses › « Électricité » (step 6.5, decision H7 of phase 6):
/// per year, the price of the economic view, the kWh, the days covered and
/// the three ratios; the lines of a year with their kWh.
class ElectricityPage extends StatelessWidget {
  const ElectricityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final current = context.read<AppServices>().today().year;
    final years = ledger.electricityYears(currentYear: current).reversed.toList();
    final orphans = ledger.orphanReadings;
    return Scaffold(
      appBar: AppBar(title: Text(l.electricityTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ModuleCategoryTile(module: ModuleKind.electricity, year: current),
          if (years.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l.electricityNone)),
          for (final year in years)
            () {
              final result = ledger.electricityYear(year);
              Widget figure(String key, String label, String? value) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(value ?? '–', key: ValueKey('electricity-$year-$key')),
                  ],
                ),
              );
              return Card(
                key: ValueKey('electricityYear-$year'),
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: InkWell(
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => ElectricityYearPage(year: year))),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('$year', style: theme.textTheme.titleMedium)),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        figure('price', l.electricityPrice, formatAmount(result.price)),
                        figure('kwh', l.electricityKwh, _kwh(result.wh)),
                        figure('days', l.electricityDays, '${result.days}'),
                        figure(
                          'perDay',
                          l.electricityPerDay,
                          result.pricePerDay == null ? null : formatAmount(result.pricePerDay!),
                        ),
                        figure(
                          'perKwh',
                          l.electricityPerKwh,
                          result.pricePerKwh == null ? null : formatDecimal(result.pricePerKwh!, 4),
                        ),
                        figure(
                          'kwhPerDay',
                          l.electricityKwhPerDay,
                          result.kwhPerDay == null ? null : formatDecimal(result.kwhPerDay!, 2),
                        ),
                        if (result.linesWithoutKwh > 0)
                          Text(
                            l.electricityMissing(result.linesWithoutKwh),
                            key: ValueKey('electricityMissing-$year'),
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }(),
          if (orphans.isNotEmpty) ...[
            const Divider(),
            ListTile(title: Text(l.electricityOrphans), subtitle: Text(l.electricityOrphansHint)),
            for (final reading in orphans)
              ListTile(
                key: ValueKey('electricityOrphan-${reading.lineId}'),
                leading: const Icon(Icons.link_off),
                title: Text(l.electricityLineKwh(_kwh(reading.wh))),
                trailing: IconButton(
                  tooltip: l.electricityErase,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => applyToLedger(context, (ledger) => ledger.setElectricity(reading.lineId, null)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The lines of the electricity category that count in [year], with their
/// kWh, entered line by line.
class ElectricityYearPage extends StatelessWidget {
  const ElectricityYearPage({super.key, required this.year});

  final int year;

  Future<void> _enter(BuildContext context, ElectricityLine line) async {
    final l = AppLocalizations.of(context);
    final result = await showDialog<_KwhInput>(
      context: context,
      builder: (_) => _KwhDialog(current: line.reading?.wh),
    );
    if (result == null || !context.mounted) return;
    if (result.invalid) {
      showMessage(context, l.electricityInvalid);
      return;
    }
    await applyToLedger(context, (ledger) => ledger.setElectricity(line.line.ownLineId, result.wh));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final result = ledger.electricityYear(year);
    return Scaffold(
      appBar: AppBar(title: Text(l.electricityLines('$year'))),
      body: ListView(
        children: [
          for (final line in result.lines)
            ListTile(
              key: ValueKey('electricityLine-${line.line.ownLineId}'),
              title: Text(titleText(l, ledger, line.line.transaction)),
              subtitle: Text(
                '${l.electricityLine(DateField.text(line.line.paid), DateField.text(line.line.start), DateField.text(line.line.end), '${line.days}')} · ${formatAmount(line.amount)}',
              ),
              trailing: Text(
                line.reading == null ? l.electricityNoKwh : l.electricityLineKwh(_kwh(line.reading!.wh)),
                key: ValueKey('electricityKwh-${line.line.ownLineId}'),
              ),
              onTap: () => _enter(context, line),
            ),
        ],
      ),
    );
  }
}

class _KwhInput {
  const _KwhInput(this.wh, {this.invalid = false});

  final int? wh;
  final bool invalid;
}

class _KwhDialog extends StatefulWidget {
  const _KwhDialog({required this.current});

  final int? current;

  @override
  State<_KwhDialog> createState() => _KwhDialogState();
}

class _KwhDialogState extends State<_KwhDialog> {
  late final _controller = TextEditingController(text: widget.current == null ? '' : _kwh(widget.current!));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.electricityEnter),
      content: TextField(
        key: const Key('electricityKwh'),
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: l.electricityKwh),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            key: const Key('electricityErase'),
            onPressed: () => Navigator.of(context).pop(const _KwhInput(null)),
            child: Text(l.electricityErase),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          key: const Key('electricitySave'),
          onPressed: () {
            final wh = parseScaled(_controller.text, 3);
            Navigator.of(context).pop(_KwhInput(wh, invalid: wh == null));
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
