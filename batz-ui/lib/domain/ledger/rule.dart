import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../ids.dart';
import '../period_model.dart';
import 'category.dart';

/// Journal entity and fields of a mapping rule of a year.
abstract final class RuleFields {
  static const entity = 'rule';
  static const year = 'year';

  /// The keywords, as a JSON list of strings: the journal holds scalars.
  static const keywords = 'keywords';

  /// The target: a category of the year's tree, or an account for a
  /// transfer. Exactly one is set.
  static const targetCategoryId = 'targetCategoryId';
  static const targetAccountId = 'targetAccountId';
  static const periodModel = 'periodModel';
  static const periodMonths = 'periodMonths';
}

/// A keyword written `re:…` is a regular expression.
const regexKeywordPrefix = 're:';

/// The form under which keywords and texts are compared: lower case, without
/// accents, every run of spaces or line breaks one space.
String normalizeText(String text) => normalizeName(text.replaceAll(RegExp(r'\s+'), ' '));

/// One keyword of a rule, ready to match a normalised text.
class Keyword {
  /// Throws a [FormatException] for an invalid regular expression.
  factory Keyword(String keyword) {
    final text = keyword.trim();
    if (text.startsWith(regexKeywordPrefix)) {
      final pattern = stripAccents(text.substring(regexKeywordPrefix.length).trim());
      if (pattern.isEmpty) throw const FormatException('empty regular expression');
      return Keyword._(text, RegExp(pattern, caseSensitive: false, unicode: true), null);
    }
    return Keyword._(text, null, normalizeText(text));
  }

  Keyword._(this.text, this._regex, this._plain);

  final String text;
  final RegExp? _regex;
  final String? _plain;

  bool get isRegex => _regex != null;

  /// Whether this keyword is in [normalized], a text from [normalizeText].
  bool matches(String normalized) => _regex?.hasMatch(normalized) ?? normalized.contains(_plain!);

  /// The form two keywords are the same under.
  String get key => _regex == null ? _plain! : '$regexKeywordPrefix${_regex.pattern}';
}

/// A mapping rule of a year: when all its keywords are in the raw text of a
/// line, it proposes its target and its period.
class MappingRule extends Equatable {
  MappingRule({
    required this.id,
    required this.year,
    required List<String> keywords,
    this.targetCategoryId,
    this.targetAccountId,
    this.periodModel,
    this.periodMonths,
  }) : keywords = List.unmodifiable(keywords),
       _compiled = _compile(keywords);

  final String id;
  final int year;

  /// As written, at least one.
  final List<String> keywords;
  final String? targetCategoryId;
  final String? targetAccountId;
  final PeriodModel? periodModel;
  final int? periodMonths;

  /// The keywords that compile, without duplicates; a rule received from
  /// another device with an invalid expression simply never matches.
  final List<Keyword>? _compiled;

  static List<Keyword>? _compile(List<String> keywords) {
    try {
      final byKey = <String, Keyword>{};
      for (final k in keywords) {
        final keyword = Keyword(k);
        byKey[keyword.key] = keyword;
      }
      return byKey.isEmpty ? null : byKey.values.toList();
    } on FormatException {
      return null;
    }
  }

  bool get isTransfer => targetAccountId != null;

  /// The number of distinct keywords: the rule with the most wins.
  int get weight => _compiled?.length ?? 0;

  /// Whether every keyword is in [normalized] (a text from [normalizeText]).
  bool matches(String normalized) => _compiled != null && _compiled.every((k) => k.matches(normalized));

  /// What the rule proposes, compared between rules of equal weight:
  /// the same target and the same period model are no conflict.
  (String?, String?, PeriodModel?, int?) get result => (
    targetCategoryId,
    targetAccountId,
    isTransfer ? null : periodModel,
    isTransfer || !(periodModel?.takesMonths ?? false) ? null : periodMonths,
  );

  @override
  List<Object?> get props => [id, year, keywords, targetCategoryId, targetAccountId, periodModel, periodMonths];
}

/// What the user enters to create or modify a rule.
class RuleDraft {
  const RuleDraft({
    required this.year,
    required this.keywords,
    this.targetCategoryId,
    this.targetAccountId,
    this.periodModel,
    this.periodMonths,
  });

  factory RuleDraft.of(MappingRule rule) => RuleDraft(
    year: rule.year,
    keywords: rule.keywords,
    targetCategoryId: rule.targetCategoryId,
    targetAccountId: rule.targetAccountId,
    periodModel: rule.periodModel,
    periodMonths: rule.periodMonths,
  );

  final int year;
  final List<String> keywords;
  final String? targetCategoryId;
  final String? targetAccountId;
  final PeriodModel? periodModel;
  final int? periodMonths;
}

String encodeKeywords(List<String> keywords) => jsonEncode(keywords);

/// The keywords of their JSON form, or null if it is not a list of strings.
List<String>? decodeKeywords(Object? value) {
  if (value is! String) return null;
  try {
    final list = jsonDecode(value);
    if (list is! List || list.any((k) => k is! String)) return null;
    return list.cast<String>();
  } on FormatException {
    return null;
  }
}

/// Identifier of the copy, in [year], of the rule [sourceId]: computed like
/// the copies of categories, which rules follow.
String copiedRuleId(String sourceId, int year) => derivedId('rule-copy/$sourceId/$year');

/// The keyword « Créer une règle » starts with for a line whose bank text is
/// [rawText] and whose description is [description]: always a keyword found
/// in that text as rules read it, so that the rule classifies at least that
/// line as long as its keywords are kept.
///
/// The description is usually the short label: lines of the bank text
/// joined by spaces, generic lines (a card number, an IBAN) left out between
/// them, so that it is not always in the text as a whole. The keyword is the
/// longest run of consecutive words of the description found in the text,
/// the first one among equals, with at least three letters or digits (« du »
/// alone would match most lines). When there is none (the user wrote their
/// own description), it is the line of the text with the most letters, the
/// first line left aside when there are others: it names the type of
/// operation. Null when the text is empty.
String? suggestedKeyword(String description, String rawText) {
  final text = normalizeText(rawText);
  if (text.trim().isEmpty) return null;
  bool found(String candidate) {
    // A keyword written `re:…` would be read as a regular expression.
    if (candidate.startsWith(regexKeywordPrefix)) return false;
    final plain = normalizeText(candidate);
    return plain.isNotEmpty && text.contains(plain);
  }

  int count(RegExp pattern, String s) => pattern.allMatches(s).length;
  final alphanumeric = RegExp(r'[\p{L}\p{N}]', unicode: true), letter = RegExp(r'\p{L}', unicode: true);

  final words = description.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  for (var length = words.length; length > 0; length--) {
    for (var start = 0; start + length <= words.length; start++) {
      final candidate = words.sublist(start, start + length).join(' ');
      if (count(alphanumeric, candidate) >= 3 && found(candidate)) return candidate;
    }
  }
  final lines = [
    for (final line in rawText.split('\n'))
      if (line.trim().isNotEmpty) line.trim().replaceAll(RegExp(r'\s+'), ' '),
  ];
  for (final candidates in [lines.length > 1 ? lines.sublist(1) : lines, lines]) {
    String? best;
    for (final line in candidates) {
      if (found(line) && (best == null || count(letter, line) > count(letter, best))) best = line;
    }
    if (best != null) return best;
  }
  return null;
}
