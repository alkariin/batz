import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'data/files.dart';
import 'data/ledger/ledger_repository.dart';
import 'data/local/database.dart';
import 'data/local/journal.dart';
import 'data/local/open_database.dart';
import 'data/secret_store.dart';
import 'data/server/server_repository.dart';
import 'data/sync/sync_engine.dart';
import 'data/sync/sync_store.dart';
import 'pages/import/import_cubit.dart';
import 'pages/sync/sync_cubit.dart';

/// Long-lived objects created once at start-up.
class AppServices {
  AppServices({
    required this.database,
    required this.journal,
    required this.secrets,
    this.syncTransport,
    this.importTransport,
    FileAccess? files,
  }) : server = ServerRepository(secrets),
       files = files ?? SystemFileAccess(),
       ledger = LedgerRepository(database, journal),
       syncStore = SyncStore(database) {
    syncEngine = SyncEngine(journal, syncStore);
  }

  /// Opens the local database (encrypted on Android) and its journal, which
  /// creates the device identifier on the very first launch.
  static Future<AppServices> open() async {
    final secrets = SystemSecretStore();
    final database = await openLocalDatabase(
      directory: await getApplicationSupportDirectory(),
      secrets: secrets,
      encrypt: Platform.isAndroid,
    );
    final journal = await Journal.open(database);
    return AppServices(database: database, journal: journal, secrets: secrets);
  }

  final LocalDatabase database;
  final Journal journal;
  final SecretStore secrets;
  final ServerRepository server;
  final LedgerRepository ledger;
  final SyncStore syncStore;
  late final SyncEngine syncEngine;

  /// How the synchronisation reaches the server; the pinned HTTPS client
  /// when null. Tests put a server in memory here.
  final TransportFactory? syncTransport;

  /// How the import reaches the server; the pinned HTTPS client when null.
  final ImportTransportFactory? importTransport;

  /// The system dialogs that pick and save files.
  final FileAccess files;
}
