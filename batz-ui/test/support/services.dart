import 'package:batz/data/local/database.dart';
import 'package:batz/data/local/journal.dart';
import 'package:batz/data/secret_store.dart';
import 'package:batz/services.dart';
import 'package:drift/native.dart';

/// App services on an in-memory database and secret store.
Future<AppServices> testServices() async {
  final database = LocalDatabase(NativeDatabase.memory());
  return AppServices(database: database, journal: await Journal.open(database), secrets: MemorySecretStore());
}
