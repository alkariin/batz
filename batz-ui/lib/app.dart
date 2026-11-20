import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'helpers/theme.dart';
import 'l10n/app_localizations.dart';
import 'pages/shell.dart';

class BatzApp extends StatelessWidget {
  const BatzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: const Locale('fr', 'CH'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(),
    );
  }
}
