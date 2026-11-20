import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A page with a title and nothing else yet.
class EmptyPage extends StatelessWidget {
  const EmptyPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(AppLocalizations.of(context).emptyPage)),
    );
  }
}
