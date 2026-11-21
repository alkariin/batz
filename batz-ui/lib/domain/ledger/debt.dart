import 'package:equatable/equatable.dart';

import '../calendar_date.dart';
import '../journal/journal_entry.dart';
import 'ledger.dart';
import 'ledger_exception.dart';
import 'redistribution.dart';

/// Journal entity and fields of a debt: a table of its own, independent
/// of the transactions.
abstract final class DebtFields {
  static const entity = 'debt';
  static const direction = 'direction';
  static const person = 'person';

  /// In cents, more than zero.
  static const amount = 'amount';

  /// The percentage of [amount] that is owed, in hundredths of a
  /// percent: 10000 is 100 %.
  static const basisPoints = 'basisPoints';
  static const eventDate = 'eventDate';
  static const invoiceDate = 'invoiceDate';
  static const requestDate = 'requestDate';
  static const receivedDate = 'receivedDate';
  static const description = 'description';
  static const repaid = 'repaid';

  /// The day the debt was entered, and the day it was checked as repaid:
  /// written by the app, they serve when the event date or the date of
  /// receipt is missing.
  static const enteredOn = 'enteredOn';
  static const checkedOn = 'checkedOn';
}

/// Who owes whom: « on me doit » adds to the wealth, « je dois » takes from
/// it.
enum DebtDirection { owedToMe, iOwe }

/// A line of the debts table.
class Debt extends Equatable {
  const Debt({
    required this.id,
    required this.direction,
    required this.person,
    required this.amount,
    required this.basisPoints,
    required this.enteredOn,
    this.eventDate,
    this.invoiceDate,
    this.requestDate,
    this.receivedDate,
    this.description = '',
    this.repaid = false,
    this.checkedOn,
  });

  final String id;
  final DebtDirection direction;
  final String person;
  final int amount;
  final int basisPoints;
  final CalendarDate? eventDate;
  final CalendarDate? invoiceDate;
  final CalendarDate? requestDate;
  final CalendarDate? receivedDate;
  final String description;
  final bool repaid;
  final CalendarDate enteredOn;
  final CalendarDate? checkedOn;

  /// The amount times the percentage, rounded to the cent, halves away from
  /// zero (the rounding of the redistribution).
  int get total => debtTotal(amount, basisPoints);

  /// [total], positive when it is owed to me, negative when I owe it.
  int get signedTotal => direction == DebtDirection.owedToMe ? total : -total;

  /// The first day the debt counts in the wealth: the day of the event, or
  /// failing that, the day it was entered.
  CalendarDate get start => eventDate ?? enteredOn;

  /// The first day it no longer counts, once repaid: the day of receipt, or
  /// failing that, the day it was checked. Null while it is not repaid. A
  /// debt repaid with neither date (only another version could write one)
  /// counts on no day.
  CalendarDate? get end => repaid ? receivedDate ?? checkedOn ?? start : null;

  /// Whether the debt counts in the wealth at the end of [date]: from its
  /// [start] to the day before its [end].
  bool countsAt(CalendarDate date) {
    if (date.isBefore(start)) return false;
    final end = this.end;
    return end == null || date.isBefore(end);
  }

  @override
  List<Object?> get props => [
    id,
    direction,
    person,
    amount,
    basisPoints,
    eventDate,
    invoiceDate,
    requestDate,
    receivedDate,
    description,
    repaid,
    enteredOn,
    checkedOn,
  ];
}

/// [amount] × [basisPoints] ÷ 10 000, rounded to the cent, halves away from
/// zero.
int debtTotal(int amount, int basisPoints) => redistributedCents(amount, basisPoints);

/// What the user enters for a debt: every field of a debt. The entry and check
/// days are written by the app.
class DebtDraft {
  const DebtDraft({
    required this.direction,
    required this.person,
    required this.amount,
    this.basisPoints = fullBasisPoints,
    this.eventDate,
    this.invoiceDate,
    this.requestDate,
    this.receivedDate,
    this.description = '',
    this.repaid = false,
  });

  factory DebtDraft.of(Debt debt) => DebtDraft(
    direction: debt.direction,
    person: debt.person,
    amount: debt.amount,
    basisPoints: debt.basisPoints,
    eventDate: debt.eventDate,
    invoiceDate: debt.invoiceDate,
    requestDate: debt.requestDate,
    receivedDate: debt.receivedDate,
    description: debt.description,
    repaid: debt.repaid,
  );

  final DebtDirection direction;
  final String person;
  final int amount;
  final int basisPoints;
  final CalendarDate? eventDate;
  final CalendarDate? invoiceDate;
  final CalendarDate? requestDate;
  final CalendarDate? receivedDate;
  final String description;
  final bool repaid;
}

/// The totals of the debts that count at one date.
class DebtTotals extends Equatable {
  const DebtTotals({required this.owedToMe, required this.iOwe});

  /// What is owed to me, and what I owe, both positive.
  final int owedToMe;
  final int iOwe;

  /// What the wealth counts: what is owed to me minus what I owe.
  int get net => owedToMe - iOwe;

  @override
  List<Object?> get props => [owedToMe, iOwe];
}

/// The debts of a [Ledger] and their operations, apart from the ledger's
/// core.
extension DebtOperations on Ledger {
  /// The debts, those not repaid first, then by start date, most recent
  /// first, then by person.
  List<Debt> get sortedDebts => debts.values.toList()
    ..sort((a, b) {
      if (a.repaid != b.repaid) return a.repaid ? 1 : -1;
      final byStart = b.start.compareTo(a.start);
      if (byStart != 0) return byStart;
      final byPerson = a.person.toLowerCase().compareTo(b.person.toLowerCase());
      return byPerson != 0 ? byPerson : a.id.compareTo(b.id);
    });

  /// The signed sum of the debts that count at the end of [date]: what the
  /// line « Dettes » of the wealth shows, whether a debts account exists
  /// or not.
  int openDebtsAt(CalendarDate date) =>
      debts.values.fold(0, (sum, debt) => debt.countsAt(date) ? sum + debt.signedTotal : sum);

  /// The totals « on me doit » and « je dois » of the debts that count at
  /// the end of [date].
  DebtTotals debtTotalsAt(CalendarDate date) {
    var owedToMe = 0, iOwe = 0;
    for (final debt in debts.values) {
      if (!debt.countsAt(date)) continue;
      if (debt.direction == DebtDirection.owedToMe) {
        owedToMe += debt.total;
      } else {
        iOwe += debt.total;
      }
    }
    return DebtTotals(owedToMe: owedToMe, iOwe: iOwe);
  }

  /// Creates the debt [id], entered [today]. Refused, with its reason: no
  /// person, an amount of zero or less, a percentage out of 0.01 to 100 %, a
  /// date of receipt before the event. Checked as repaid at once, it is
  /// checked [today].
  Modification createDebt(String id, DebtDraft draft, {required CalendarDate today}) {
    _checkDebt(draft);
    return Modification.set(DebtFields.entity, id, {
      ..._debtFields(draft),
      DebtFields.enteredOn: today.encode(),
      DebtFields.checkedOn: draft.repaid ? today.encode() : null,
    });
  }

  /// Modifies the debt [id] under the same rules. Checking it as repaid
  /// records [today] as the day it was checked; unchecking clears it.
  Modification updateDebt(String id, DebtDraft draft, {required CalendarDate today}) {
    final debt = _debt(id);
    _checkDebt(draft);
    return Modification.set(DebtFields.entity, id, {
      ..._debtFields(draft),
      if (draft.repaid != debt.repaid) DebtFields.checkedOn: draft.repaid ? today.encode() : null,
    });
  }

  /// Checks the debt [id] as repaid [today], received on [receivedDate]
  /// (the screen proposes today).
  Modification checkDebt(String id, {required CalendarDate? receivedDate, required CalendarDate today}) {
    final debt = _debt(id);
    final draft = DebtDraft.of(debt);
    return updateDebt(
      id,
      DebtDraft(
        direction: draft.direction,
        person: draft.person,
        amount: draft.amount,
        basisPoints: draft.basisPoints,
        eventDate: draft.eventDate,
        invoiceDate: draft.invoiceDate,
        requestDate: draft.requestDate,
        receivedDate: receivedDate,
        description: draft.description,
        repaid: true,
      ),
      today: today,
    );
  }

  /// Unchecks the debt [id]: it counts again, its date of receipt kept.
  Modification uncheckDebt(String id) {
    _debt(id);
    return Modification.set(DebtFields.entity, id, {DebtFields.repaid: false, DebtFields.checkedOn: null});
  }

  Modification deleteDebt(String id) {
    _debt(id);
    return Modification.delete(DebtFields.entity, id);
  }

  /// Splits the debt [id] in two: [firstCents], taken from its total,
  /// stays on it; the rest goes to the new debt [newId]. Both keep
  /// direction, person, dates, description and state, and carry their part
  /// as amount, at 100 %: their totals add up exactly to the total of the
  /// original. Refused when [firstCents] is not strictly between zero and
  /// the total.
  Modification splitDebt(String id, String newId, int firstCents) {
    final debt = _debt(id);
    if (firstCents <= 0 || firstCents >= debt.total) throw const LedgerException(LedgerError.debtSplitOutOfTotal);
    String? encode(CalendarDate? date) => date?.encode();
    return Modification([
      for (final field in {DebtFields.amount: firstCents, DebtFields.basisPoints: fullBasisPoints}.entries)
        FieldChange(DebtFields.entity, id, field.key, field.value),
      for (final field in {
        DebtFields.direction: debt.direction.name,
        DebtFields.person: debt.person,
        DebtFields.amount: debt.total - firstCents,
        DebtFields.basisPoints: fullBasisPoints,
        DebtFields.eventDate: encode(debt.eventDate),
        DebtFields.invoiceDate: encode(debt.invoiceDate),
        DebtFields.requestDate: encode(debt.requestDate),
        DebtFields.receivedDate: encode(debt.receivedDate),
        DebtFields.description: debt.description,
        DebtFields.repaid: debt.repaid,
        DebtFields.enteredOn: debt.enteredOn.encode(),
        DebtFields.checkedOn: encode(debt.checkedOn),
      }.entries)
        FieldChange(DebtFields.entity, newId, field.key, field.value),
    ]);
  }

  Debt _debt(String id) {
    final debt = debts[id];
    if (debt == null) throw const LedgerException(LedgerError.unknownDebt);
    return debt;
  }

  void _checkDebt(DebtDraft draft) {
    if (draft.person.trim().isEmpty) throw const LedgerException(LedgerError.debtPersonRequired);
    if (draft.amount <= 0) throw const LedgerException(LedgerError.amountRequired);
    if (draft.basisPoints < 1 || draft.basisPoints > fullBasisPoints) {
      throw const LedgerException(LedgerError.debtPercentInvalid);
    }
    final event = draft.eventDate, received = draft.receivedDate;
    if (event != null && received != null && received.isBefore(event)) {
      throw const LedgerException(LedgerError.debtReceivedBeforeEvent);
    }
  }

  static Map<String, Object?> _debtFields(DebtDraft draft) => {
    DebtFields.direction: draft.direction.name,
    DebtFields.person: draft.person.trim(),
    DebtFields.amount: draft.amount,
    DebtFields.basisPoints: draft.basisPoints,
    DebtFields.eventDate: draft.eventDate?.encode(),
    DebtFields.invoiceDate: draft.invoiceDate?.encode(),
    DebtFields.requestDate: draft.requestDate?.encode(),
    DebtFields.receivedDate: draft.receivedDate?.encode(),
    DebtFields.description: draft.description.trim(),
    DebtFields.repaid: draft.repaid,
  };
}
