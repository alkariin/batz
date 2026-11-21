/// Subscriptions: informative, linked to nothing else. A subscription has
/// tranches; a change of price or a resumption is a new tranche.
library;

import 'package:equatable/equatable.dart';

import '../calendar_date.dart';
import '../journal/journal_entry.dart';
import '../ledger/ledger.dart';
import '../ledger/ledger_exception.dart';

/// Journal entity and fields of a subscription (« Subscription »).
abstract final class SubscriptionFields {
  static const entity = 'subscription';
  static const name = 'name';
  static const note = 'note';
}

/// Journal entity and fields of a tranche (« SubscriptionTranche »).
abstract final class TrancheFields {
  static const entity = 'subscriptionTranche';
  static const subscriptionId = 'subscriptionId';

  /// In cents, more than zero.
  static const amount = 'amount';
  static const frequency = 'frequency';
  static const start = 'start';

  /// The last day; absent while it goes on.
  static const end = 'end';
}

enum TrancheFrequency { monthly, yearly }

class Tranche extends Equatable {
  const Tranche({
    required this.id,
    required this.subscriptionId,
    required this.amount,
    required this.frequency,
    required this.start,
    this.end,
  });

  final String id;
  final String subscriptionId;
  final int amount;
  final TrancheFrequency frequency;
  final CalendarDate start;
  final CalendarDate? end;

  /// The amount if monthly; the amount ÷ 12, to the cent, if yearly.
  int get monthlyCost => frequency == TrancheFrequency.monthly ? amount : _twelfth(amount);

  /// The amount × 12 if monthly; the amount if yearly.
  int get yearlyCost => frequency == TrancheFrequency.monthly ? amount * 12 : amount;

  bool covers(CalendarDate date) => !date.isBefore(start) && (end == null || !date.isAfter(end!));

  bool overlaps(Tranche other) => _overlap(start, end, other.start, other.end);

  @override
  List<Object?> get props => [id, subscriptionId, amount, frequency, start, end];
}

int _twelfth(int cents) => (cents * 2 + 12) ~/ 24;

bool _overlap(CalendarDate aStart, CalendarDate? aEnd, CalendarDate bStart, CalendarDate? bEnd) =>
    (aEnd == null || !bStart.isAfter(aEnd)) && (bEnd == null || !aStart.isAfter(bEnd));

enum SubscriptionState { current, upcoming, ended }

class Subscription extends Equatable {
  Subscription({required this.id, required this.name, this.note = '', Iterable<Tranche> tranches = const []})
    : tranches = List<Tranche>.unmodifiable(
        <Tranche>[...tranches]..sort((a, b) {
          final byStart = a.start.compareTo(b.start);
          return byStart != 0 ? byStart : a.id.compareTo(b.id);
        }),
      );

  final String id;
  final String name;
  final String note;

  /// By start.
  final List<Tranche> tranches;

  Subscription withTranches(Iterable<Tranche> tranches) =>
      Subscription(id: id, name: name, note: note, tranches: tranches);

  /// The tranche that covers [date]; when a merge left two, the one that
  /// started last.
  Tranche? trancheAt(CalendarDate date) {
    Tranche? found;
    for (final t in tranches) {
      if (t.covers(date)) found = t;
    }
    return found;
  }

  SubscriptionState stateAt(CalendarDate date) {
    if (trancheAt(date) != null) return SubscriptionState.current;
    if (tranches.any((t) => t.start.isAfter(date))) return SubscriptionState.upcoming;
    return SubscriptionState.ended;
  }

  /// Whether two of its tranches overlap: only a merge can leave them so.
  bool get hasOverlap {
    for (var i = 0; i < tranches.length; i++) {
      for (var j = i + 1; j < tranches.length; j++) {
        if (tranches[i].overlaps(tranches[j])) return true;
      }
    }
    return false;
  }

  @override
  List<Object?> get props => [id, name, note, tranches];
}

/// What the user enters for a tranche.
class TrancheDraft {
  const TrancheDraft({required this.amount, required this.frequency, required this.start, this.end});

  final int amount;
  final TrancheFrequency frequency;
  final CalendarDate start;
  final CalendarDate? end;
}

/// The subscriptions seen on a day: current, to come, ended, and the totals
/// of the current ones.
class SubscriptionsAt {
  SubscriptionsAt(this.date, Iterable<Subscription> subscriptions)
    : all = [...subscriptions]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final CalendarDate date;
  final List<Subscription> all;

  List<Subscription> inState(SubscriptionState state) => [
    for (final s in all)
      if (s.stateAt(date) == state) s,
  ];

  /// The sums of the monthly and of the yearly costs shown, current
  /// subscriptions only.
  int get monthlyTotal => inState(SubscriptionState.current).fold(0, (sum, s) => sum + s.trancheAt(date)!.monthlyCost);
  int get yearlyTotal => inState(SubscriptionState.current).fold(0, (sum, s) => sum + s.trancheAt(date)!.yearlyCost);
}

/// The subscriptions and their operations.
extension SubscriptionOperations on Ledger {
  SubscriptionsAt subscriptionsAt(CalendarDate date) => SubscriptionsAt(date, modules.subscriptions.values);

  /// Creates the subscription [id] with its first tranche [trancheId].
  /// Refused without a name, or for a tranche refused by [addTranche].
  Modification createSubscription(
    String id,
    String trancheId, {
    required String name,
    String note = '',
    required TrancheDraft first,
  }) {
    if (name.trim().isEmpty) throw const LedgerException(LedgerError.nameRequired);
    _checkTranche(first);
    return Modification([
      for (final field in {SubscriptionFields.name: name.trim(), SubscriptionFields.note: note.trim()}.entries)
        FieldChange(SubscriptionFields.entity, id, field.key, field.value),
      ..._trancheChanges(trancheId, id, first),
    ]);
  }

  Modification updateSubscription(String id, {required String name, String note = ''}) {
    _subscription(id);
    if (name.trim().isEmpty) throw const LedgerException(LedgerError.nameRequired);
    return Modification.set(SubscriptionFields.entity, id, {
      SubscriptionFields.name: name.trim(),
      SubscriptionFields.note: note.trim(),
    });
  }

  /// Deletes the subscription [id] and its tranches.
  Modification deleteSubscription(String id) {
    final subscription = _subscription(id);
    return Modification([
      FieldChange(SubscriptionFields.entity, id, deletedField, true),
      for (final t in subscription.tranches) FieldChange(TrancheFields.entity, t.id, deletedField, true),
    ]);
  }

  /// Adds the tranche [trancheId] to [subscriptionId]: the tranche before
  /// it that has no end is closed the day before it starts. Refused, with
  /// its reason: an amount of zero or less, an end before the start, a
  /// tranche that overlaps another.
  Modification addTranche(String subscriptionId, String trancheId, TrancheDraft draft) {
    final subscription = _subscription(subscriptionId);
    _checkTranche(draft);
    Tranche? previous;
    for (final t in subscription.tranches) {
      if (t.start.isBefore(draft.start) && t.end == null) previous = t;
    }
    final others = [for (final t in subscription.tranches) t == previous ? _closed(t, draft.start.addDays(-1)) : t];
    if (others.any((t) => _overlap(t.start, t.end, draft.start, draft.end))) {
      throw const LedgerException(LedgerError.trancheOverlap);
    }
    return Modification([
      ..._trancheChanges(trancheId, subscriptionId, draft),
      if (previous != null)
        FieldChange(TrancheFields.entity, previous.id, TrancheFields.end, draft.start.addDays(-1).encode()),
    ]);
  }

  /// Modifies the tranche [id] under the same rules, without closing any.
  Modification updateTranche(String id, TrancheDraft draft) {
    final tranche = _tranche(id);
    _checkTranche(draft);
    final subscription = _subscription(tranche.subscriptionId);
    if (subscription.tranches.any((t) => t.id != id && _overlap(t.start, t.end, draft.start, draft.end))) {
      throw const LedgerException(LedgerError.trancheOverlap);
    }
    return Modification(_trancheChanges(id, tranche.subscriptionId, draft));
  }

  Modification deleteTranche(String id) {
    _tranche(id);
    return Modification.delete(TrancheFields.entity, id);
  }

  Subscription _subscription(String id) {
    final subscription = modules.subscriptions[id];
    if (subscription == null) throw const LedgerException(LedgerError.unknownSubscription);
    return subscription;
  }

  Tranche _tranche(String id) {
    for (final s in modules.subscriptions.values) {
      for (final t in s.tranches) {
        if (t.id == id) return t;
      }
    }
    throw const LedgerException(LedgerError.unknownSubscription);
  }

  static Tranche _closed(Tranche t, CalendarDate end) => Tranche(
    id: t.id,
    subscriptionId: t.subscriptionId,
    amount: t.amount,
    frequency: t.frequency,
    start: t.start,
    end: end,
  );

  static void _checkTranche(TrancheDraft draft) {
    if (draft.amount <= 0) throw const LedgerException(LedgerError.amountRequired);
    if (draft.end != null && draft.end!.isBefore(draft.start)) {
      throw const LedgerException(LedgerError.trancheEndBeforeStart);
    }
  }

  static List<FieldChange> _trancheChanges(String id, String subscriptionId, TrancheDraft draft) => [
    for (final field in {
      TrancheFields.subscriptionId: subscriptionId,
      TrancheFields.amount: draft.amount,
      TrancheFields.frequency: draft.frequency.name,
      TrancheFields.start: draft.start.encode(),
      TrancheFields.end: draft.end?.encode(),
    }.entries)
      FieldChange(TrancheFields.entity, id, field.key, field.value),
  ];
}
