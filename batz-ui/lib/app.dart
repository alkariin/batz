import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'helpers/theme.dart';
import 'l10n/app_localizations.dart';
import 'pages/ledger_cubit.dart';
import 'pages/server/server_cubit.dart';
import 'pages/shell.dart';
import 'pages/sync/sync_cubit.dart';
import 'services.dart';

class BatzApp extends StatelessWidget {
  const BatzApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: services,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ServerCubit(services.server)..load()),
          BlocProvider(create: (_) => LedgerCubit(services.ledger)..load()),
          BlocProvider(
            create: (context) {
              final ledger = context.read<LedgerCubit>();
              return SyncCubit(
                server: services.server,
                journal: services.journal,
                engine: services.syncEngine,
                store: services.syncStore,
                transport: services.syncTransport,
                onReceived: ledger.load,
              )..start();
            },
            lazy: false,
          ),
        ],
        // A new pairing, or a forgotten one, restarts the synchronisation.
        child: BlocListener<ServerCubit, ServerState>(
          listenWhen: (previous, current) => previous.pairing?.deviceId != current.pairing?.deviceId,
          listener: (context, _) => context.read<SyncCubit>().pairingChanged(),
          child: _material(home: const AppShell()),
        ),
      ),
    );
  }
}

/// Shown when the app cannot start, typically when the local database
/// cannot be opened.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return _material(
      home: Builder(
        builder: (context) {
          final l = AppLocalizations.of(context);
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.startupErrorTitle, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    Text(l.startupErrorBody),
                    const SizedBox(height: 12),
                    SelectableText('$error', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

MaterialApp _material({required Widget home}) {
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
    home: home,
  );
}
