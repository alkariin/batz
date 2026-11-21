import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/server/server_client.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/statement.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';

/// The statements of a detailed account, latest first: period, balances,
/// number of lines; the original PDF can be saved, the latest statement
/// deleted.
class StatementsPage extends StatelessWidget {
  const StatementsPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final statements = ledger.statementsOf(accountId).reversed.toList();
    final last = ledger.lastStatementOf(accountId);
    return Scaffold(
      appBar: AppBar(title: Text(l.statementsTitle(ledger.accounts[accountId]?.name ?? '?'))),
      body: statements.isEmpty
          ? Center(child: Text(l.statementsEmpty))
          : ListView(
              children: [
                for (final s in statements)
                  ListTile(
                    key: ValueKey('statement-${s.id}'),
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(_period(l, s)),
                    subtitle: Text(
                      l.statementSummary(
                        formatAmount(s.openingBalance),
                        formatAmount(s.closingBalance),
                        ledger.linesOf(s.id).length,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      key: ValueKey('statementMenu-${s.id}'),
                      onSelected: (action) => action == 'pdf' ? _savePdf(context, s) : _delete(context, ledger, s),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'pdf', child: Text(l.statementSavePdf)),
                        if (s.id == last?.id) PopupMenuItem(value: 'delete', child: Text(l.statementDeleteLast)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  static String _period(AppLocalizations l, Statement s) =>
      l.statementPeriod(formatDate(s.periodStart.toDateTime()), formatDate(s.periodEnd.toDateTime()));

  /// Fetches the original file from the server, under its fingerprint, and
  /// lets the user save it. A server rebuilt since the import no longer has
  /// it: the app says so, without error.
  Future<void> _savePdf(BuildContext context, Statement s) async {
    final l = AppLocalizations.of(context);
    final services = context.read<AppServices>();
    final pairing = await services.server.pairing();
    if (!context.mounted) return;
    if (pairing == null) {
      showMessage(context, l.statementPdfNotPaired);
      return;
    }
    final transport =
        services.importTransport?.call(pairing) ??
        ServerClient(pairing.address, pin: pairing.fingerprint, deviceKey: pairing.deviceKey);
    try {
      final pdf = await transport.statementPdf(s.fingerprint);
      if (!context.mounted) return;
      if (pdf == null) {
        showMessage(context, l.statementPdfMissing);
        return;
      }
      final name = 'releve-${s.periodStart.encode()}-${s.periodEnd.encode()}.pdf';
      if (await services.files.savePdf(name, pdf) && context.mounted) showMessage(context, l.statementPdfSaved);
    } on ServerUnreachableException {
      if (context.mounted) showMessage(context, l.statementPdfUnreachable);
    } on ServerException catch (e) {
      if (context.mounted) showMessage(context, l.importServerRefused(e.code));
    } finally {
      if (transport case final ServerClient client) client.close();
    }
  }

  Future<void> _delete(BuildContext context, Ledger ledger, Statement s) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          l.statementDeleteConfirm(
            formatDate(s.periodStart.toDateTime()),
            formatDate(s.periodEnd.toDateTime()),
            ledger.linesOf(s.id).length,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (await applyToLedger(context, (ledger) => ledger.deleteLastStatement(s.id)) && context.mounted) {
      showMessage(context, l.statementDeleted);
    }
  }
}
