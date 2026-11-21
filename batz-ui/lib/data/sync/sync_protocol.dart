import '../../domain/journal/hlc.dart';
import '../../domain/journal/journal_entry.dart';
import '../../domain/journal/known_state.dart';

/// Version of the exchange protocol this app speaks (docs/architecture.md, « Synchronisation »).
const syncProtocol = 1;

/// The server answered something this app cannot read, or broke the
/// protocol.
class SyncProtocolException implements Exception {
  SyncProtocolException(this.message);

  final String message;

  @override
  String toString() => 'SyncProtocolException: $message';
}

/// One call of an exchange: the app's known state, and a page of entries the
/// server lacks.
class SyncRequest {
  SyncRequest({required this.appVersion, required this.known, required this.page, this.limit});

  final String appVersion;
  final KnownState known;
  final JournalPage page;

  /// The largest page the app wants back.
  final int? limit;

  Map<String, Object?> toJson() => {
    'protocol': syncProtocol,
    'appVersion': appVersion,
    'known': known.toJson(),
    'since': page.since.toJson(),
    'entries': [for (final e in page.entries) entryToJson(e)],
    'limit': ?limit,
  };
}

/// The server's answer: its state after integrating the app's page, and a
/// page of what the app lacks.
class SyncResponse {
  SyncResponse({required this.serverTime, required this.known, required this.page, required this.added});

  /// Reads the body of `POST /api/v1/sync`; throws [SyncProtocolException]
  /// if it is malformed.
  factory SyncResponse.fromJson(Object? json) {
    try {
      final body = json! as Map<String, Object?>;
      if (body['protocol'] != syncProtocol) throw SyncProtocolException('protocol ${body['protocol']}');
      return SyncResponse(
        serverTime: DateTime.parse(body['serverTime']! as String),
        known: KnownState.fromJson(body['known']! as Map<String, Object?>),
        page: JournalPage(
          [for (final e in body['entries']! as List<Object?>) entryFromJson(e! as Map<String, Object?>)],
          since: KnownState.fromJson(body['since']! as Map<String, Object?>),
          more: body['more']! as bool,
        ),
        added: body['added']! as int,
      );
    } on SyncProtocolException {
      rethrow;
    } catch (e) {
      throw SyncProtocolException('malformed answer: $e');
    }
  }

  final DateTime serverTime;
  final KnownState known;
  final JournalPage page;

  /// How many entries of the app's page were new to the server.
  final int added;
}

/// An entry on the wire; the value is its JSON text, which the server keeps
/// unchanged.
Map<String, String> entryToJson(JournalEntry entry) => {
  'hlc': entry.hlc.encode(),
  'entity': entry.entity,
  'recordId': entry.recordId,
  'field': entry.field,
  'value': entry.encodedValue,
};

JournalEntry entryFromJson(Map<String, Object?> json) => JournalEntry(
  Hlc.parse(json['hlc']! as String),
  FieldChange(
    json['entity']! as String,
    json['recordId']! as String,
    json['field']! as String,
    JournalEntry.decodeValue(json['value']! as String),
  ),
);
