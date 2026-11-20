import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/sync/sync_engine.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../server/server_page.dart';
import 'sync_cubit.dart';

/// The state of the synchronisation, its last date, the modifications
/// waiting to be sent, and the button: on the home screen and in
/// Plus › Serveur.
class SyncCard extends StatelessWidget {
  const SyncCard({super.key, this.showPairing = true});

  /// Whether to offer pairing when no server is paired.
  final bool showPairing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<SyncCubit, SyncState>(
      builder: (context, state) {
        if (state.status == SyncStatus.notPaired) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_off_outlined),
                      const SizedBox(width: 12),
                      Text(l.syncTitle, style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(l.syncNotPaired, key: const Key('syncStatus')),
                  if (showPairing)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ServerPage())),
                        child: Text(l.syncPairAction),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
        final syncing = state.status == SyncStatus.syncing;
        final last = state.lastSync?.toLocal();
        final (icon, title) = switch (state.status) {
          SyncStatus.neverSynced => (Icons.cloud_queue, l.syncNever),
          SyncStatus.syncing => (Icons.sync, l.syncRunning),
          SyncStatus.upToDate => (Icons.cloud_done_outlined, l.syncUpToDate),
          SyncStatus.offline => (Icons.cloud_off_outlined, l.syncOffline),
          SyncStatus.revoked => (Icons.block, l.syncRevoked),
          SyncStatus.incompatible => (Icons.warning_amber_outlined, l.syncIncompatible),
          SyncStatus.decisionNeeded => (Icons.call_merge, l.syncDecision),
          SyncStatus.error || SyncStatus.notPaired => (Icons.error_outline, l.syncError),
        };
        final problem = switch (state.status) {
          SyncStatus.offline => l.syncOfflineHint,
          SyncStatus.revoked => l.syncRevokedHint,
          SyncStatus.incompatible => switch (state.incompatibility) {
            Incompatibility.appTooOld => l.syncAppTooOld(state.minAppVersion ?? ''),
            _ => l.syncServerTooOld(state.serverVersion ?? ''),
          },
          SyncStatus.error => l.syncErrorHint(state.error ?? ''),
          SyncStatus.decisionNeeded => l.syncDecisionHint,
          _ => null,
        };
        final colors = theme.colorScheme;
        final alarming = {SyncStatus.revoked, SyncStatus.incompatible, SyncStatus.error}.contains(state.status);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: alarming ? colors.error : null),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title, key: const Key('syncStatus'), style: theme.textTheme.titleMedium),
                    ),
                    if (syncing) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 8),
                if (last != null) Text(l.syncLast(formatDate(last), formatTime(last))),
                Text(l.syncPending(state.pending), key: const Key('syncPending')),
                if (problem != null) ...[
                  const SizedBox(height: 8),
                  Text(problem, style: alarming ? TextStyle(color: colors.error) : null),
                ],
                if (state.clockWarning) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.syncClockWarning(state.clockOffset!.inMinutes.abs()),
                    key: const Key('syncClockWarning'),
                    style: TextStyle(color: colors.error),
                  ),
                ],
                if (state.status == SyncStatus.decisionNeeded)
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      FilledButton(
                        key: const Key('syncMerge'),
                        onPressed: () => context.read<SyncCubit>().merge(),
                        child: Text(l.syncMerge),
                      ),
                      OutlinedButton(
                        key: const Key('syncReplace'),
                        onPressed: () => confirmReplace(context),
                        child: Text(l.syncReplace),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      key: const Key('syncNow'),
                      onPressed: syncing ? null : () => context.read<SyncCubit>().sync(manual: true),
                      icon: const Icon(Icons.sync),
                      label: Text(l.syncNow),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Asks for confirmation, then replaces the data of this device by the
/// server's (decision H1).
Future<void> confirmReplace(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final cubit = context.read<SyncCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(l.syncReplaceConfirm),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(
          key: const Key('syncReplaceConfirm'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.confirm),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await cubit.replace();
  if (cubit.state.status == SyncStatus.upToDate) {
    messenger.showSnackBar(SnackBar(content: Text(l.syncReplaceDone)));
  }
}
