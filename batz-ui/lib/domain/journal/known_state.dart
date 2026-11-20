import 'hlc.dart';
import 'journal_entry.dart';

/// A known state: for each origin device, the timestamp of the latest of its
/// entries a copy of the journal holds.
///
/// Every copy (device or server) holds the entries of each origin from the
/// first one, without a gap (batz-web/docs/sync.md). The known state is thus
/// enough to tell what a copy lacks: the entries of each origin after its
/// timestamp, and every entry of an origin it does not know.
class KnownState {
  KnownState([Map<String, Hlc> latest = const {}]) : latest = Map.unmodifiable(latest) {
    for (final MapEntry(key: origin, value: hlc) in latest.entries) {
      if (hlc.deviceId != origin) throw ArgumentError.value(hlc, 'latest', 'not a timestamp of $origin');
    }
  }

  /// Parses the wire form: origin to encoded timestamp.
  factory KnownState.fromJson(Map<String, Object?> json) =>
      KnownState({for (final MapEntry(:key, :value) in json.entries) key: Hlc.parse(value! as String)});

  static final empty = KnownState();

  final Map<String, Hlc> latest;

  bool get isEmpty => latest.isEmpty;

  Set<String> get origins => latest.keys.toSet();

  /// Whether a copy with this state holds the entries stamped [hlc].
  bool holds(Hlc hlc) {
    final mine = latest[hlc.deviceId];
    return mine != null && hlc.compareTo(mine) <= 0;
  }

  /// This state restricted to [origins].
  KnownState only(Iterable<String> origins) => KnownState({for (final origin in origins) origin: ?latest[origin]});

  /// This state extended by [entries].
  KnownState plus(Iterable<JournalEntry> entries) {
    final result = {...latest};
    for (final entry in entries) {
      final current = result[entry.deviceId];
      if (current == null || entry.hlc > current) result[entry.deviceId] = entry.hlc;
    }
    return KnownState(result);
  }

  Map<String, String> toJson() => {for (final MapEntry(:key, :value) in latest.entries) key: value.encode()};

  @override
  bool operator ==(Object other) =>
      other is KnownState &&
      other.latest.length == latest.length &&
      latest.entries.every((e) => other.latest[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered(latest.entries.map((e) => Object.hash(e.key, e.value)));

  @override
  String toString() => 'KnownState(${toJson()})';
}

/// Entries one copy of the journal sends another, in one call: sorted by
/// timestamp, never cutting a modification.
class JournalPage {
  JournalPage(this.entries, {KnownState? since, this.more = false}) : since = since ?? KnownState.empty;

  static final empty = JournalPage(const []);

  final List<JournalEntry> entries;

  /// The receiver's known state the page was computed from, for the origins
  /// of its entries: it continues from there. The receiver refuses a page
  /// that continues from more than it holds, which would leave a gap.
  final KnownState since;

  /// Whether the sender may hold more entries the receiver lacks.
  final bool more;

  bool get isEmpty => entries.isEmpty;

  /// Number of modifications in the page.
  int get modifications => {for (final e in entries) e.hlc}.length;
}
