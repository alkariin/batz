import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../sync/sync_card.dart';
import 'tasks_card.dart';

/// Accueil: the state of the synchronisation and the tasks to do
/// (specification, 4.6).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).navHome)),
      body: ListView(padding: const EdgeInsets.all(16), children: const [SyncCard(), SizedBox(height: 8), TasksCard()]),
    );
  }
}
