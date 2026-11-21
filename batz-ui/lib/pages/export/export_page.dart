import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/export/export_archive.dart';
import '../../l10n/app_localizations.dart';
import '../../services.dart';
import '../../version.dart';
import '../ledger_cubit.dart';

/// « Plus › Réglages › Exporter les données »: what the export holds, that
/// the file is not encrypted, then the save dialog of the system. The export
/// reads the ledger of this device; it writes nothing but the file the user
/// saves.
class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

sealed class _Outcome {
  const _Outcome();
}

class _Saved extends _Outcome {
  const _Saved(this.archive);
  final ExportArchive archive;
}

class _Cancelled extends _Outcome {
  const _Cancelled();
}

class _Failed extends _Outcome {
  const _Failed(this.error);
  final Object error;
}

class _ExportPageState extends State<ExportPage> {
  bool _working = false;
  _Outcome? _outcome;

  Future<void> _export() async {
    final services = context.read<AppServices>();
    final cubit = context.read<LedgerCubit>();
    setState(() {
      _working = true;
      _outcome = null;
    });
    _Outcome outcome;
    try {
      if (!cubit.state.loaded) await cubit.load();
      // Lets the progress indicator show before the files are built.
      await Future<void>.delayed(Duration.zero);
      final archive = buildExportArchive(cubit.state.ledger, date: services.today(), appVersion: appVersion);
      final saved = await services.files.saveZip(archive.fileName, archive.bytes);
      outcome = saved ? _Saved(archive) : const _Cancelled();
    } catch (e) {
      outcome = _Failed(e);
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _outcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.exportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.exportContents),
          const SizedBox(height: 12),
          Text(l.exportNotIncluded),
          const SizedBox(height: 16),
          Card(
            key: const Key('exportNotEncrypted'),
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.lock_open, color: theme.colorScheme.onErrorContainer),
              title: Text(l.exportNotEncrypted, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            ),
          ),
          const SizedBox(height: 8),
          Text(l.exportOffline, style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('exportButton'),
              onPressed: _working ? null : _export,
              icon: const Icon(Icons.file_download_outlined),
              label: Text(l.exportButton),
            ),
          ),
          const SizedBox(height: 16),
          if (_working)
            Row(
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text(l.exportWorking),
              ],
            ),
          if (_outcome case final outcome?)
            Text(
              switch (outcome) {
                _Saved(:final archive) => l.exportSaved(archive.csvFiles, archive.transactions),
                _Cancelled() => l.exportCancelled,
                _Failed(:final error) => l.exportFailed('$error'),
              },
              key: const Key('exportOutcome'),
              style: outcome is _Failed ? TextStyle(color: theme.colorScheme.error) : null,
            ),
        ],
      ),
    );
  }
}
