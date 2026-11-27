import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'data/device_lock.dart';
import 'data/documents/document_store.dart';
import 'data/documents/documents.dart';
import 'data/files.dart';
import 'data/ledger/ledger_repository.dart';
import 'data/local/database.dart';
import 'data/local/journal.dart';
import 'data/local/open_database.dart';
import 'data/local/preferences_store.dart';
import 'data/secret_store.dart';
import 'data/server/server_repository.dart';
import 'data/sync/sync_engine.dart';
import 'data/sync/sync_store.dart';
import 'domain/calendar_date.dart';
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
    DocumentTransportFactory? documentTransport,
    FileAccess? files,
    this.today = CalendarDate.today,
    this.deviceLock,
    this.now = DateTime.now,
  }) : server = ServerRepository(secrets),
       files = files ?? SystemFileAccess(),
       ledger = LedgerRepository(database, journal),
       documents = Documents(DocumentStore(database), ServerRepository(secrets), transport: documentTransport),
       preferences = PreferencesStore(database),
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
    return AppServices(
      database: database,
      journal: journal,
      secrets: secrets,
      // The app is behind the lock of the device on Android
      // only.
      deviceLock: Platform.isAndroid ? SystemDeviceLock() : null,
    );
  }

  final LocalDatabase database;
  final Journal journal;
  final SecretStore secrets;
  final ServerRepository server;
  final LedgerRepository ledger;
  final PreferencesStore preferences;
  final SyncStore syncStore;
  late final SyncEngine syncEngine;

  /// How the synchronisation reaches the server; the pinned HTTPS client
  /// when null. Tests put a server in memory here.
  final TransportFactory? syncTransport;

  /// How the import reaches the server; the pinned HTTPS client when null.
  final ImportTransportFactory? importTransport;

  /// The system dialogs that pick and save files.
  final FileAccess files;

  /// The files of the documents of the insurances: on the server and copied
  /// here.
  final Documents documents;

  /// Today on this device's calendar: the day balances may be declared up
  /// to, debts are entered and checked, and the wealth is seen. Tests set
  /// the day.
  final CalendarDate Function() today;

  /// The lock of the device the app stands behind; null where there is
  /// none to ask (Windows, Ubuntu, and the tests that do not set one).
  final DeviceLock? deviceLock;

  /// The clock of this device, read when the app leaves the screen and
  /// when it comes back. Tests set it.
  final DateTime Function() now;
}
