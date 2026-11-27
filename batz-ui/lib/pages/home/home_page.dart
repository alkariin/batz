import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../monthly/monthly_card.dart';
import '../sync/sync_card.dart';
import 'key_figures_card.dart';
import 'tasks_card.dart';

/// Accueil: the state of the synchronisation, the tasks to do, the month to
/// finish and the key figures of the year.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).navHome)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SyncCard(),
          SizedBox(height: 8),
          TasksCard(),
          SizedBox(height: 8),
          MonthlyCard(),
          SizedBox(height: 8),
          KeyFiguresCard(),
        ],
      ),
    );
  }
}
