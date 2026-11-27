/// Insurances: for each one the user names, its tranches (one period of the
/// contract each, from a start to an optional end), and on each tranche its
/// documents (contract, policy, other), its links and its note. Linked to
/// nothing else. The files of the documents are kept by the server and
/// copied on every device; the journal holds what describes them.
library;

import 'package:equatable/equatable.dart';

import '../calendar_date.dart';
import '../journal/journal_entry.dart';
import '../ledger/ledger.dart';
import '../ledger/ledger_exception.dart';

/// Journal entity and fields of an insurance.
abstract final class InsuranceFields {
  static const entity = 'insurance';
  static const name = 'name';
}

/// Journal entity and fields of a tranche of an insurance.
abstract final class InsuranceTrancheFields {
  static const entity = 'insuranceTranche';
  static const insuranceId = 'insuranceId';
  static const start = 'start';

  /// The last day; absent while it goes on.
  static const end = 'end';
  static const note = 'note';
}

/// Journal entity and fields of a document of a tranche: what describes the
/// file the server keeps under its fingerprint.
abstract final class InsuranceDocumentFields {
  static const entity = 'insuranceDocument';
  static const trancheId = 'trancheId';
  static const kind = 'kind';
  static const name = 'name';

  /// SHA-256 of the file, lower-case hex.
  static const fingerprint = 'fingerprint';

  /// In bytes.
  static const size = 'size';
  static const mediaType = 'mediaType';
}

/// Journal entity and fields of a link of a tranche.
abstract final class InsuranceLinkFields {
  static const entity = 'insuranceLink';
  static const trancheId = 'trancheId';
  static const label = 'label';
  static const url = 'url';
}

enum InsuranceDocumentKind { contract, policy, other }

class InsuranceDocument extends Equatable {
  const InsuranceDocument({
    required this.id,
    required this.trancheId,
    required this.kind,
    required this.name,
    required this.fingerprint,
    required this.size,
    required this.mediaType,
  });

  final String id;
  final String trancheId;
  final InsuranceDocumentKind kind;
  final String name;
  final String fingerprint;
  final int size;
  final String mediaType;

  @override
  List<Object?> get props => [id, trancheId, kind, name, fingerprint, size, mediaType];
}

class InsuranceLink extends Equatable {
  const InsuranceLink({required this.id, required this.trancheId, required this.label, required this.url});

  final String id;
  final String trancheId;
  final String label;
  final String url;

  @override
  List<Object?> get props => [id, trancheId, label, url];
}

class InsuranceTranche extends Equatable {
  InsuranceTranche({
    required this.id,
    required this.insuranceId,
    required this.start,
    this.end,
    this.note = '',
    Iterable<InsuranceDocument> documents = const [],
    Iterable<InsuranceLink> links = const [],
  }) : documents = List<InsuranceDocument>.unmodifiable(
         <InsuranceDocument>[...documents]..sort((a, b) {
           final byKind = a.kind.index.compareTo(b.kind.index);
           if (byKind != 0) return byKind;
           final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
           return byName != 0 ? byName : a.id.compareTo(b.id);
         }),
       ),
       links = List<InsuranceLink>.unmodifiable(
         <InsuranceLink>[...links]..sort((a, b) {
           final byLabel = a.label.toLowerCase().compareTo(b.label.toLowerCase());
           return byLabel != 0 ? byLabel : a.id.compareTo(b.id);
         }),
       );

  final String id;
  final String insuranceId;
  final CalendarDate start;
  final CalendarDate? end;
  final String note;

  /// By kind (contract, policy, other), then name.
  final List<InsuranceDocument> documents;

  /// By label.
  final List<InsuranceLink> links;

  bool covers(CalendarDate date) => !date.isBefore(start) && (end == null || !date.isAfter(end!));

  InsuranceTranche withContent(Iterable<InsuranceDocument> documents, Iterable<InsuranceLink> links) =>
      InsuranceTranche(
        id: id,
        insuranceId: insuranceId,
        start: start,
        end: end,
        note: note,
        documents: documents,
        links: links,
      );

  @override
  List<Object?> get props => [id, insuranceId, start, end, note, documents, links];
}

class Insurance extends Equatable {
  Insurance({required this.id, required this.name, Iterable<InsuranceTranche> tranches = const []})
    : tranches = List<InsuranceTranche>.unmodifiable(
        <InsuranceTranche>[...tranches]..sort((a, b) {
          final byStart = a.start.compareTo(b.start);
          return byStart != 0 ? byStart : a.id.compareTo(b.id);
        }),
      );

  final String id;
  final String name;

  /// By start.
  final List<InsuranceTranche> tranches;

  Insurance withTranches(Iterable<InsuranceTranche> tranches) => Insurance(id: id, name: name, tranches: tranches);

  /// The tranche that covers [date]: the one active that day; when a merge
  /// left two, the one that started last.
  InsuranceTranche? activeAt(CalendarDate date) {
    InsuranceTranche? found;
    for (final t in tranches) {
      if (t.covers(date)) found = t;
    }
    return found;
  }

  @override
  List<Object?> get props => [id, name, tranches];
}

/// What the user enters for a tranche.
class InsuranceTrancheDraft {
  const InsuranceTrancheDraft({required this.start, this.end, this.note = ''});

  final CalendarDate start;
  final CalendarDate? end;
  final String note;
}

/// What describes a document once the server keeps its file.
class InsuranceDocumentDraft {
  const InsuranceDocumentDraft({
    required this.kind,
    required this.name,
    required this.fingerprint,
    required this.size,
    required this.mediaType,
  });

  final InsuranceDocumentKind kind;
  final String name;
  final String fingerprint;
  final int size;
  final String mediaType;
}

final _fingerprint = RegExp(r'^[0-9a-f]{64}$');

/// Whether [url] is an address a browser opens: `http://` or `https://`
/// and a host.
bool isInsuranceLink(String url) {
  final uri = Uri.tryParse(url.trim());
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
}

/// The insurances and their operations.
extension InsuranceOperations on Ledger {
  /// The insurances, by name.
  List<Insurance> get insurances => [...modules.insurances.values]
    ..sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });

  /// Creates the insurance [id] with its first tranche [trancheId]. Refused
  /// without a name, or for a tranche whose end comes before its start.
  Modification createInsurance(
    String id,
    String trancheId, {
    required String name,
    required InsuranceTrancheDraft first,
  }) {
    if (name.trim().isEmpty) throw const LedgerException(LedgerError.nameRequired);
    _checkTranche(first);
    return Modification([
      FieldChange(InsuranceFields.entity, id, InsuranceFields.name, name.trim()),
      ..._trancheChanges(trancheId, id, first),
    ]);
  }

  Modification renameInsurance(String id, String name) {
    _insurance(id);
    if (name.trim().isEmpty) throw const LedgerException(LedgerError.nameRequired);
    return Modification.set(InsuranceFields.entity, id, {InsuranceFields.name: name.trim()});
  }

  /// Deletes the insurance [id], its tranches, their documents and links.
  Modification deleteInsurance(String id) {
    final insurance = _insurance(id);
    return Modification([
      FieldChange(InsuranceFields.entity, id, deletedField, true),
      for (final t in insurance.tranches) ..._trancheDeletion(t),
    ]);
  }

  /// Adds the tranche [trancheId] to [insuranceId]: the tranche before it
  /// that has no end is closed the day before it starts. Refused, with its
  /// reason: an end before the start, a tranche that overlaps another.
  Modification addInsuranceTranche(String insuranceId, String trancheId, InsuranceTrancheDraft draft) {
    final insurance = _insurance(insuranceId);
    _checkTranche(draft);
    InsuranceTranche? previous;
    for (final t in insurance.tranches) {
      if (t.start.isBefore(draft.start) && t.end == null) previous = t;
    }
    final closedEnd = draft.start.addDays(-1);
    for (final t in insurance.tranches) {
      final end = t == previous ? closedEnd : t.end;
      if (_overlap(t.start, end, draft.start, draft.end)) throw const LedgerException(LedgerError.trancheOverlap);
    }
    return Modification([
      ..._trancheChanges(trancheId, insuranceId, draft),
      if (previous != null)
        FieldChange(InsuranceTrancheFields.entity, previous.id, InsuranceTrancheFields.end, closedEnd.encode()),
    ]);
  }

  /// Modifies the tranche [id] under the same rules, without closing any.
  Modification updateInsuranceTranche(String id, InsuranceTrancheDraft draft) {
    final tranche = _tranche(id);
    _checkTranche(draft);
    final insurance = _insurance(tranche.insuranceId);
    if (insurance.tranches.any((t) => t.id != id && _overlap(t.start, t.end, draft.start, draft.end))) {
      throw const LedgerException(LedgerError.trancheOverlap);
    }
    return Modification(_trancheChanges(id, tranche.insuranceId, draft));
  }

  /// Deletes the tranche [id], its documents and its links.
  Modification deleteInsuranceTranche(String id) => Modification(_trancheDeletion(_tranche(id)));

  /// Adds the document [documentId], whose file the server keeps, to the
  /// tranche [trancheId]. Refused without a name or with a fingerprint that
  /// is not one.
  Modification addInsuranceDocument(String trancheId, String documentId, InsuranceDocumentDraft draft) {
    _tranche(trancheId);
    if (draft.name.trim().isEmpty) throw const LedgerException(LedgerError.nameRequired);
    if (!_fingerprint.hasMatch(draft.fingerprint) || draft.size <= 0) {
      throw const LedgerException(LedgerError.insuranceDocumentInvalid);
    }
    return Modification.set(InsuranceDocumentFields.entity, documentId, {
      InsuranceDocumentFields.trancheId: trancheId,
      InsuranceDocumentFields.kind: draft.kind.name,
      InsuranceDocumentFields.name: draft.name.trim(),
      InsuranceDocumentFields.fingerprint: draft.fingerprint,
      InsuranceDocumentFields.size: draft.size,
      InsuranceDocumentFields.mediaType: draft.mediaType,
    });
  }

  /// Changes the kind and the name of the document [id]; its file stays.
  Modification updateInsuranceDocument(String id, {required InsuranceDocumentKind kind, required String name}) {
    _document(id);
    if (name.trim().isEmpty) throw const LedgerException(LedgerError.nameRequired);
    return Modification.set(InsuranceDocumentFields.entity, id, {
      InsuranceDocumentFields.kind: kind.name,
      InsuranceDocumentFields.name: name.trim(),
    });
  }

  Modification deleteInsuranceDocument(String id) {
    _document(id);
    return Modification.delete(InsuranceDocumentFields.entity, id);
  }

  /// Adds the link [linkId] to the tranche [trancheId]. Refused when the
  /// address is not one a browser opens; without a label, the address is
  /// its label.
  Modification addInsuranceLink(String trancheId, String linkId, {required String label, required String url}) {
    _tranche(trancheId);
    return Modification.set(InsuranceLinkFields.entity, linkId, {
      InsuranceLinkFields.trancheId: trancheId,
      ..._linkFields(label, url),
    });
  }

  Modification updateInsuranceLink(String id, {required String label, required String url}) {
    _link(id);
    return Modification.set(InsuranceLinkFields.entity, id, _linkFields(label, url));
  }

  Modification deleteInsuranceLink(String id) {
    _link(id);
    return Modification.delete(InsuranceLinkFields.entity, id);
  }

  /// The fingerprints of every document: the files each device keeps.
  Set<String> get insuranceFingerprints => {
    for (final i in modules.insurances.values)
      for (final t in i.tranches)
        for (final d in t.documents) d.fingerprint,
  };

  Map<String, Object?> _linkFields(String label, String url) {
    if (!isInsuranceLink(url)) throw const LedgerException(LedgerError.insuranceLinkInvalid);
    return {
      InsuranceLinkFields.label: label.trim().isEmpty ? url.trim() : label.trim(),
      InsuranceLinkFields.url: url.trim(),
    };
  }

  Insurance _insurance(String id) {
    final insurance = modules.insurances[id];
    if (insurance == null) throw const LedgerException(LedgerError.unknownInsurance);
    return insurance;
  }

  InsuranceTranche _tranche(String id) {
    for (final i in modules.insurances.values) {
      for (final t in i.tranches) {
        if (t.id == id) return t;
      }
    }
    throw const LedgerException(LedgerError.unknownInsurance);
  }

  InsuranceDocument _document(String id) {
    for (final i in modules.insurances.values) {
      for (final t in i.tranches) {
        for (final d in t.documents) {
          if (d.id == id) return d;
        }
      }
    }
    throw const LedgerException(LedgerError.unknownInsurance);
  }

  InsuranceLink _link(String id) {
    for (final i in modules.insurances.values) {
      for (final t in i.tranches) {
        for (final l in t.links) {
          if (l.id == id) return l;
        }
      }
    }
    throw const LedgerException(LedgerError.unknownInsurance);
  }

  static List<FieldChange> _trancheDeletion(InsuranceTranche t) => [
    FieldChange(InsuranceTrancheFields.entity, t.id, deletedField, true),
    for (final d in t.documents) FieldChange(InsuranceDocumentFields.entity, d.id, deletedField, true),
    for (final l in t.links) FieldChange(InsuranceLinkFields.entity, l.id, deletedField, true),
  ];

  static void _checkTranche(InsuranceTrancheDraft draft) {
    if (draft.end != null && draft.end!.isBefore(draft.start)) {
      throw const LedgerException(LedgerError.trancheEndBeforeStart);
    }
  }

  static List<FieldChange> _trancheChanges(String id, String insuranceId, InsuranceTrancheDraft draft) => [
    for (final field in {
      InsuranceTrancheFields.insuranceId: insuranceId,
      InsuranceTrancheFields.start: draft.start.encode(),
      InsuranceTrancheFields.end: draft.end?.encode(),
      InsuranceTrancheFields.note: draft.note.trim(),
    }.entries)
      FieldChange(InsuranceTrancheFields.entity, id, field.key, field.value),
  ];
}

bool _overlap(CalendarDate aStart, CalendarDate? aEnd, CalendarDate bStart, CalendarDate? bEnd) =>
    (aEnd == null || !bStart.isAfter(aEnd)) && (bEnd == null || !aStart.isAfter(bEnd));
