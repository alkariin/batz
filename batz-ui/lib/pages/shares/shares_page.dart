import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ledger/category.dart';
import '../../domain/views/share_operations.dart';
import '../../domain/views/year_view.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';
import '../transactions/transaction_detail_page.dart';
import '../transactions/transaction_texts.dart';
import '../year/year_texts.dart';

/// « Parts à classer »: the shares carried to a year that has no category of
/// the same name, grouped by category of origin and year. One answer serves
/// a group; a line can be answered alone. Nothing waits on it: meanwhile the
/// shares count in « À classer ».
class SharesPage extends StatelessWidget {
  const SharesPage({super.key, this.year});

  /// Only the questions of this year, from its « À classer » line.
  final int? year;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final groups = [
      for (final g in ledger.views.pendingShares)
        if (year == null || g.year == year) g,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.sharesTitle)),
      body: groups.isEmpty
          ? Center(child: Text(l.sharesEmpty))
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [for (final group in groups) _GroupCard(group: group)],
            ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  const _GroupCard({required this.group});

  final PendingShareGroup group;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  String? _category;

  Future<void> _classify(Iterable<String> lineIds, String? categoryId) async {
    final l = AppLocalizations.of(context);
    if (categoryId == null) {
      showMessage(context, l.sharesChoose);
      return;
    }
    final group = widget.group;
    if (await applyToLedger(context, (ledger) => ledger.classifyShares(group.year, lineIds, categoryId)) && mounted) {
      showMessage(context, l.sharesClassified);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final group = widget.group;
    final tree = ledger.views.treeOf(group.year)!;
    // Categories of the year that can receive the shares: the same nature.
    final categories = [
      for (final c in tree.assignable)
        if (tree.natureOf(c.id) == group.nature) c,
    ];
    final key = '${group.origin.id}-${group.year}';
    DropdownMenuItem<String> item(Category c) => DropdownMenuItem(value: c.id, child: Text(c.name));
    return Card(
      key: ValueKey('shares-$key'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.sharesGroup(group.origin.name, '${group.originYear}', '${group.year}'),
              style: theme.textTheme.titleMedium,
            ),
            Text(
              '${natureText(l, group.nature)} · ${l.sharesExplain('${group.year}', group.origin.name)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final share in group.shares)
              ListTile(
                key: ValueKey('share-${share.lineId}-${group.year}'),
                contentPadding: EdgeInsets.zero,
                title: Text(titleText(l, ledger, share.transaction)),
                subtitle: Text(
                  [
                    formatDate(share.transaction.date.toDateTime()),
                    if (share.economic != 0) '${l.yearViewEconomic} ${shownAmount(share.economic, group.nature)}',
                    if (share.cash != 0) '${l.yearViewCash} ${shownAmount(share.cash, group.nature)}',
                  ].join(' · '),
                ),
                trailing: PopupMenuButton<String>(
                  key: ValueKey('shareLine-${share.lineId}-${group.year}'),
                  tooltip: l.sharesLineCategory,
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (_) => [for (final c in categories) PopupMenuItem(value: c.id, child: Text(c.name))],
                  onSelected: (id) => _classify([share.lineId], id),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => TransactionDetailPage(transactionId: share.transaction.id)),
                ),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('sharesCategory-$key'),
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.sharesCategory('${group.year}')),
              items: [for (final c in categories) item(c)],
              onChanged: (id) => setState(() => _category = id),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: ValueKey('sharesClassify-$key'),
                onPressed: () => _classify(group.shares.map((s) => s.lineId), _category),
                child: Text(l.sharesClassifyGroup),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
