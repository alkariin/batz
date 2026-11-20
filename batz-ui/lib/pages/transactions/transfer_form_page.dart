import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../components/date_field.dart';
import '../../domain/calendar_date.dart';
import '../../domain/ids.dart';
import '../../domain/ledger/account.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/transaction.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';

/// Records a transfer between two accounts, or modifies [transaction].
class TransferFormPage extends StatefulWidget {
  const TransferFormPage({super.key, this.transaction});

  final LedgerTransaction? transaction;

  @override
  State<TransferFormPage> createState() => _TransferFormPageState();
}

class _TransferFormPageState extends State<TransferFormPage> {
  late final LedgerTransaction? _existing = widget.transaction;
  late final _amount = TextEditingController(text: _existing == null ? '' : formatAmount(-_existing.amount));
  late final _date = TextEditingController(text: DateField.text(_existing?.date ?? CalendarDate.today()));
  late final _description = TextEditingController(text: _existing?.description);
  late final _note = TextEditingController(text: _existing?.note);
  late String? _from = _existing?.accountId;
  late String? _to = _existing?.counterpartAccountId;

  @override
  void dispose() {
    for (final c in [_amount, _date, _description, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Accounts a manual transfer may use: active, not the detailed one.
  List<Account> _accounts(Ledger ledger) => [
    for (final a in ledger.sortedAccounts)
      if ((!a.archived || a.id == _existing?.accountId || a.id == _existing?.counterpartAccountId) && !a.isDetailed) a,
  ];

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final cents = parseAmount(_amount.text);
    final date = DateField.read(_date);
    final String? problem;
    if (cents == null || cents <= 0 || _amount.text.trim().startsWith('-')) {
      problem = l.errorAmountInvalid;
    } else if (date == null) {
      problem = l.errorDateInvalid;
    } else if (_from == null || _to == null) {
      problem = l.errorAccountMissing;
    } else {
      problem = null;
    }
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    final draft = TransferDraft(
      fromAccountId: _from!,
      toAccountId: _to!,
      date: date!,
      cents: cents!,
      description: _description.text,
      note: _note.text,
    );
    final existing = _existing;
    final saved = await applyToLedger(
      context,
      (ledger) => existing == null ? ledger.recordTransfer(newId(), draft) : ledger.updateTransfer(existing.id, draft),
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accounts = _accounts(context.watch<LedgerCubit>().state.ledger);
    DropdownButtonFormField<String> accountField(Key key, String label, String? value, ValueChanged<String?> set) =>
        DropdownButtonFormField<String>(
          key: key,
          initialValue: accounts.any((a) => a.id == value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
          onChanged: set,
        );

    return Scaffold(
      appBar: AppBar(title: Text(_existing == null ? l.transferNewTitle : l.transferEditTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('amount'),
            controller: _amount,
            autofocus: _existing == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.fieldAmount, suffixText: 'CHF'),
          ),
          const SizedBox(height: 12),
          DateField(fieldKey: const Key('date'), controller: _date, label: l.fieldDate),
          const SizedBox(height: 12),
          accountField(const Key('from'), l.fieldFrom, _from, (id) => setState(() => _from = id)),
          const SizedBox(height: 12),
          accountField(const Key('to'), l.fieldTo, _to, (id) => setState(() => _to = id)),
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
            maxLines: null,
            decoration: InputDecoration(labelText: l.fieldNote),
          ),
          const SizedBox(height: 24),
          FilledButton(key: const Key('save'), onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}
