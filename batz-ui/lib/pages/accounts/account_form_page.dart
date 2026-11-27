import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ids.dart';
import '../../domain/ledger/account.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/ledger_exception.dart';
import '../../l10n/app_localizations.dart';
import '../import/statements_page.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import '../wealth/account_page.dart';

/// Creates an account, or modifies, archives or removes [account].
class AccountFormPage extends StatefulWidget {
  const AccountFormPage({super.key, this.account});

  final Account? account;

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  late final _name = TextEditingController(text: widget.account?.name);
  late AccountType _type = widget.account?.type ?? AccountType.privateAccount;
  late ImportFormat? _importFormat = widget.account?.importFormat;
  late bool _archived = widget.account?.archived ?? false;
  late bool _declared = widget.account?.declared ?? false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final draft = AccountDraft(
      name: _name.text,
      type: _type,
      importFormat: _importFormat,
      archived: _archived,
      declared: _declared,
    );
    final existing = widget.account;
    final saved = await applyToLedger(
      context,
      (ledger) => existing == null ? ledger.createAccount(newId(), draft) : ledger.updateAccount(existing.id, draft),
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  Future<void> _remove(Account account) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.accountDeleteConfirm(account.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cubit = context.read<LedgerCubit>();
    try {
      final removal = cubit.state.ledger.removeAccount(account.id);
      await cubit.write(removal.modification);
      if (!mounted) return;
      showMessage(context, switch (removal) {
        AccountRemoval(transactionCount: final count) when count > 0 => l.accountArchivedInstead(count),
        AccountRemoval(balanceCount: final count) when count > 0 => l.accountArchivedBalances(count),
        _ => l.accountDeleted,
      });
      Navigator.of(context).pop();
    } on LedgerException catch (e) {
      if (mounted) showMessage(context, ledgerErrorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final account = widget.account;
    return Scaffold(
      appBar: AppBar(
        title: Text(account == null ? l.accountNew : l.accountEdit),
        actions: [
          if (account != null)
            IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: () => _remove(account)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('accountName'),
            controller: _name,
            autofocus: account == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.accountName),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AccountType>(
            key: const Key('accountType'),
            initialValue: _type,
            decoration: InputDecoration(labelText: l.accountType),
            items: [
              for (final type in AccountType.values)
                DropdownMenuItem(value: type, child: Text(accountTypeText(l, type))),
            ],
            onChanged: (type) => setState(() => _type = type ?? _type),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ImportFormat?>(
            key: const Key('accountImport'),
            initialValue: _importFormat,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.accountImport,
              helperText: _importFormat == null ? null : l.accountImportHint,
              helperMaxLines: 2,
            ),
            items: [
              DropdownMenuItem(child: Text(l.accountImportNone)),
              DropdownMenuItem(value: ImportFormat.postfinance, child: Text(l.accountImportPostfinance)),
              DropdownMenuItem(value: ImportFormat.neon, child: Text(l.accountImportNeon)),
            ],
            onChanged: (format) => setState(() => _importFormat = format),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('accountDeclared'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.accountDeclared),
            subtitle: Text(l.accountDeclaredHint),
            value: _declared,
            onChanged: (value) => setState(() => _declared = value),
          ),
          if (account != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.accountArchived),
              value: _archived,
              onChanged: (value) => setState(() => _archived = value),
            ),
          if (account != null)
            ListTile(
              key: const Key('accountBalances'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_outlined),
              title: Text(l.accountOpenBalances),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => AccountPage(accountId: account.id))),
            ),
          if (account != null && account.isDetailed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l.accountStatements),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => StatementsPage(accountId: account.id))),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}
