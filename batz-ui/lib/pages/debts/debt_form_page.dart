import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/date_field.dart';
import '../../domain/calendar_date.dart';
import '../../domain/ids.dart';
import '../../domain/ledger/debt.dart';
import '../../domain/ledger/ledger_exception.dart';
import '../../domain/ledger/redistribution.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';

/// Creates a debt, or modifies or deletes [debt] (step 5.5): every field of
/// the specification (4.7), the total computed on screen as it is typed.
class DebtFormPage extends StatefulWidget {
  const DebtFormPage({super.key, this.debt});

  final Debt? debt;

  @override
  State<DebtFormPage> createState() => _DebtFormPageState();
}

class _DebtFormPageState extends State<DebtFormPage> {
  late DebtDirection _direction = widget.debt?.direction ?? DebtDirection.owedToMe;
  late final _person = TextEditingController(text: widget.debt?.person);
  late final _amount = TextEditingController(text: widget.debt == null ? '' : formatAmount(widget.debt!.amount));
  late final _percent = TextEditingController(
    text: formatPercent(widget.debt?.basisPoints ?? fullBasisPoints).replaceFirst(' %', ''),
  );
  late final _event = _dateController(widget.debt?.eventDate);
  late final _invoice = _dateController(widget.debt?.invoiceDate);
  late final _request = _dateController(widget.debt?.requestDate);
  late final _received = _dateController(widget.debt?.receivedDate);
  late final _description = TextEditingController(text: widget.debt?.description);
  late bool _repaid = widget.debt?.repaid ?? false;
  String? _dateError;

  static TextEditingController _dateController(CalendarDate? date) =>
      TextEditingController(text: date == null ? '' : DateField.text(date));

  @override
  void dispose() {
    for (final c in [_person, _amount, _percent, _event, _invoice, _request, _received, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The total of what is typed, or null while it cannot be computed.
  int? get _total {
    final amount = parseAmount(_amount.text), basisPoints = parsePercent(_percent.text);
    if (amount == null || amount <= 0 || basisPoints == null) return null;
    return debtTotal(amount, basisPoints);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    // An empty date is no date; a date typed must be valid.
    CalendarDate? date(TextEditingController c) => c.text.trim().isEmpty ? null : DateField.read(c);
    final invalid = [_event, _invoice, _request, _received].any((c) => c.text.trim().isNotEmpty && date(c) == null);
    if (invalid) {
      setState(() => _dateError = l.debtInvalidDate);
      return;
    }
    setState(() => _dateError = null);
    final basisPoints = parsePercent(_percent.text);
    if (basisPoints == null) {
      showMessage(context, l.errorDebtPercentInvalid);
      return;
    }
    final draft = DebtDraft(
      direction: _direction,
      person: _person.text,
      amount: parseAmount(_amount.text) ?? 0,
      basisPoints: basisPoints,
      eventDate: date(_event),
      invoiceDate: date(_invoice),
      requestDate: date(_request),
      receivedDate: date(_received),
      description: _description.text,
      repaid: _repaid,
    );
    final today = context.read<AppServices>().today();
    final existing = widget.debt;
    final saved = await applyToLedger(
      context,
      (ledger) => existing == null
          ? ledger.createDebt(newId(), draft, today: today)
          : ledger.updateDebt(existing.id, draft, today: today),
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(Debt debt) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.debtDeleteConfirm(debt.person)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cubit = context.read<LedgerCubit>();
    try {
      await cubit.write(cubit.state.ledger.deleteDebt(debt.id));
    } on LedgerException catch (e) {
      if (mounted) showMessage(context, ledgerErrorText(l, e));
      return;
    }
    if (!mounted) return;
    showMessage(context, l.debtDeleted);
    Navigator.of(context).pop();
  }

  /// Checking the box proposes today as the date of receipt (H5).
  void _setRepaid(bool repaid) {
    setState(() {
      _repaid = repaid;
      if (repaid && _received.text.trim().isEmpty) {
        _received.text = DateField.text(context.read<AppServices>().today());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final debt = widget.debt;
    final total = _total;
    Widget dateField(TextEditingController controller, String label, String key) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DateField(controller: controller, label: label, fieldKey: Key(key), onChanged: () => setState(() {})),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(debt == null ? l.debtNew : l.debtEdit),
        actions: [
          if (debt != null)
            IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: () => _delete(debt)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<DebtDirection>(
            key: const Key('debtDirection'),
            segments: [
              ButtonSegment(value: DebtDirection.owedToMe, label: Text(l.debtOwedToMe)),
              ButtonSegment(value: DebtDirection.iOwe, label: Text(l.debtIOwe)),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() => _direction = s.single),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('debtPerson'),
            controller: _person,
            autofocus: debt == null,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l.debtPerson),
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  key: const Key('debtAmount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l.debtAmount),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextField(
                  key: const Key('debtPercent'),
                  controller: _percent,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l.debtPercent, suffixText: '%'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l.debtTotal(total == null ? '–' : formatAmount(total)),
              key: const Key('debtTotal'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextField(
            key: const Key('debtDescription'),
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.debtDescription),
          ),
          dateField(_event, l.debtEventDate, 'debtEventDate'),
          dateField(_invoice, l.debtInvoiceDate, 'debtInvoiceDate'),
          dateField(_request, l.debtRequestDate, 'debtRequestDate'),
          dateField(_received, l.debtReceivedDate, 'debtReceivedDate'),
          if (_dateError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_dateError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          SwitchListTile(
            key: const Key('debtRepaid'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.debtRepaid),
            value: _repaid,
            onChanged: _setRepaid,
          ),
          Text(l.debtDatesHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton(key: const Key('saveDebt'), onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}
