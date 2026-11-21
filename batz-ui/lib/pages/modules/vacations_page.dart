import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/date_field.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/modules/settings.dart';
import '../../domain/modules/vacations.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import '../transactions/transaction_detail_page.dart';
import '../transactions/transaction_texts.dart';
import 'module_category_tile.dart';

/// Plus › Analyses › « Vacances »: the trips by year, the most recent
/// first, with date, place, days, amount and price per day, the total of
/// each year; the manual lines; the sheets left without transaction.
class VacationsPage extends StatelessWidget {
  const VacationsPage({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final vacations = ledger.vacations;
    final current = context.read<AppServices>().today().year;
    return Scaffold(
      appBar: AppBar(title: Text(l.vacationsTitle)),
      floatingActionButton: FloatingActionButton(
        key: const Key('vacationsAddManual'),
        tooltip: l.vacationsNewManual,
        onPressed: () => _open(context, const TripPage(tripKey: null)),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          ModuleCategoryTile(module: ModuleKind.vacations, year: current),
          if (vacations.trips.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l.vacationsNone)),
          for (final year in vacations.years) ...[
            ListTile(
              title: Text(
                l.vacationsYearTotal('$year', formatAmount(vacations.totalOf(year))),
                key: ValueKey('vacationsYear-$year'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final trip in vacations.tripsOf(year))
              ListTile(
                key: ValueKey('trip-${trip.key}'),
                leading: Icon(
                  trip.extraSheets.isNotEmpty ? Icons.warning_amber_outlined : Icons.luggage_outlined,
                  color: trip.extraSheets.isNotEmpty ? theme.colorScheme.error : null,
                ),
                title: Text(
                  trip.place.isNotEmpty ? trip.place : (trip.isManual ? l.vacationsManual : l.vacationsNoPlace),
                ),
                subtitle: Text(
                  [
                    l.vacationsTripSubtitle(
                      DateField.text(trip.date),
                      trip.days == null ? l.vacationsNoDays : l.vacationsDays(trip.days!),
                    ),
                    if (trip.pricePerDay case final perDay?) l.vacationsPerDay(formatAmount(perDay)),
                  ].join(' · '),
                ),
                trailing: Text(formatAmount(trip.amount), key: ValueKey('tripAmount-${trip.key}')),
                onTap: () => _open(context, TripPage(tripKey: trip.key)),
              ),
          ],
          if (vacations.orphanSheets.isNotEmpty) ...[
            const Divider(),
            ListTile(title: Text(l.vacationsOrphans), subtitle: Text(l.vacationsOrphansHint)),
            for (final sheet in vacations.orphanSheets)
              ListTile(
                key: ValueKey('orphan-${sheet.id}'),
                leading: const Icon(Icons.link_off),
                title: Text(sheet.place.isEmpty ? l.vacationsNoPlace : sheet.place),
                trailing: IconButton(
                  tooltip: l.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => applyToLedger(context, (ledger) => ledger.deleteTripSheet(sheet.id)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A trip, found by its key in the current ledger, or a new manual line
/// when [tripKey] is null: place and days; for a trip of transactions, the
/// date and the amount replaced or automatic, and its transactions.
class TripPage extends StatefulWidget {
  const TripPage({super.key, required this.tripKey});

  final String? tripKey;

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  final _place = TextEditingController(), _days = TextEditingController();
  final _date = TextEditingController(), _amount = TextEditingController();
  bool _filled = false;
  late final _newId = newManualTripId();

  @override
  void dispose() {
    for (final c in [_place, _days, _date, _amount]) {
      c.dispose();
    }
    super.dispose();
  }

  Trip? _trip(Ledger ledger) {
    final key = widget.tripKey;
    if (key == null) return null;
    for (final trip in ledger.vacations.trips) {
      if (trip.key == key) return trip;
    }
    return null;
  }

  void _fill(Trip? trip) {
    if (_filled) return;
    _filled = true;
    if (trip == null) return;
    _place.text = trip.place;
    _days.text = trip.days?.toString() ?? '';
    final date = trip.isManual ? trip.date : trip.sheet?.date;
    final amount = trip.isManual ? trip.amount : trip.sheet?.amount;
    _date.text = date == null ? '' : DateField.text(date);
    _amount.text = amount == null ? '' : formatAmount(amount);
  }

  Future<void> _save(Trip? trip) async {
    final l = AppLocalizations.of(context);
    final days = _days.text.trim().isEmpty ? null : int.tryParse(_days.text.trim());
    final date = _date.text.trim().isEmpty ? null : DateField.read(_date);
    final amount = _amount.text.trim().isEmpty ? null : parseAmount(_amount.text);
    if ((_days.text.trim().isNotEmpty && days == null) ||
        (_date.text.trim().isNotEmpty && date == null) ||
        (_amount.text.trim().isNotEmpty && amount == null)) {
      showMessage(context, l.vacationsInvalid);
      return;
    }
    final saved = await applyToLedger(
      context,
      (ledger) => trip == null
          ? ledger.saveManualTrip(_newId, place: _place.text, days: days, date: date, amount: amount)
          : ledger.saveTrip(trip, place: _place.text, days: days, date: date, amount: amount),
    );
    if (saved && mounted) {
      showMessage(context, l.vacationsSaved);
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete(String id, {bool close = false}) async {
    final l = AppLocalizations.of(context);
    final deleted = await applyToLedger(context, (ledger) => ledger.deleteTripSheet(id));
    if (deleted && mounted) {
      showMessage(context, l.vacationsDeleted);
      if (close) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final trip = _trip(ledger);
    _fill(trip);
    final manual = trip == null || trip.isManual;
    Widget restore(String key, TextEditingController c) =>
        TextButton(key: ValueKey(key), onPressed: () => setState(c.clear), child: Text(l.vacationsRestore));
    return Scaffold(
      appBar: AppBar(
        title: Text(manual ? (trip == null ? l.vacationsNewManual : l.vacationsManual) : l.vacationsTrip),
        actions: [
          if (trip != null && trip.isManual)
            IconButton(
              key: const Key('tripDelete'),
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(trip.sheet!.id, close: true),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('tripPlace'),
            controller: _place,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l.vacationsPlace),
          ),
          TextField(
            key: const Key('tripDays'),
            controller: _days,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.vacationsDaysField),
          ),
          const SizedBox(height: 8),
          DateField(
            controller: _date,
            label: manual ? l.vacationsDate : l.vacationsReplaceDate,
            fieldKey: const Key('tripDate'),
            onChanged: () => setState(() {}),
          ),
          if (!manual)
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.vacationsAutomatic(DateField.text(trip.automaticDate!)),
                    key: const Key('tripAutomaticDate'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (_date.text.isNotEmpty) restore('tripRestoreDate', _date),
              ],
            ),
          TextField(
            key: const Key('tripAmount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: manual ? l.vacationsAmount : l.vacationsReplaceAmount),
            onChanged: (_) => setState(() {}),
          ),
          if (!manual)
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.vacationsAutomatic(formatAmount(trip.automaticAmount!)),
                    key: const Key('tripAutomaticAmount'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (_amount.text.isNotEmpty) restore('tripRestoreAmount', _amount),
              ],
            ),
          const SizedBox(height: 16),
          FilledButton(key: const Key('tripSave'), onPressed: () => _save(trip), child: Text(l.save)),
          if (trip != null && trip.extraSheets.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l.vacationsExtraSheets(trip.extraSheets.length), style: TextStyle(color: theme.colorScheme.error)),
            for (final sheet in trip.extraSheets)
              ListTile(
                key: ValueKey('extra-${sheet.id}'),
                title: Text(sheet.place.isEmpty ? l.vacationsNoPlace : sheet.place),
                trailing: IconButton(
                  tooltip: l.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(sheet.id),
                ),
              ),
          ],
          if (trip != null && !trip.isManual) ...[
            const SizedBox(height: 16),
            Text(l.vacationsTransactions, style: theme.textTheme.titleSmall),
            for (final line in trip.lines)
              ListTile(
                key: ValueKey('tripLine-${line.ownLineId}'),
                dense: true,
                title: Text(titleText(l, ledger, line.transaction)),
                subtitle: Text(
                  '${DateField.text(line.paid)} · ${DateField.text(line.start)} – ${DateField.text(line.end)}',
                ),
                trailing: Text(formatAmount(line.amount)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => TransactionDetailPage(transactionId: line.transaction.id)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
