import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'data/local/database.dart';
import 'data/local/journal.dart';
import 'data/local/open_database.dart';
import 'data/secret_store.dart';

/// Long-lived objects created once at start-up.
class AppServices {
  AppServices({required this.database, required this.journal, required this.secrets});

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
}
