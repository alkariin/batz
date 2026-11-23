import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// The button that explains how mapping rules work.
class RulesHelpButton extends StatelessWidget {
  const RulesHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return IconButton(
      key: const Key('rulesHelp'),
      tooltip: l.rulesHelp,
      icon: const Icon(Icons.help_outline),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.rulesHelpTitle),
          content: SingleChildScrollView(child: Text(l.rulesHelpBody, key: const Key('rulesHelpBody'))),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.close))],
        ),
      ),
    );
  }
}
