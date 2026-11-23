import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../ids.dart';
import 'category.dart';

/// Journal entity and fields of a mapping rule of a year.
abstract final class RuleFields {
  static const entity = 'rule';
  static const year = 'year';

  /// The lines of the rule, as a JSON list of strings (the journal holds
  /// scalars): the rule matches when one of them does.
  static const lines = 'lines';

  /// The keywords of a rule written before lines existed, as a JSON list of
  /// strings, all required: read as the single line `a ET b` while [lines]
  /// is absent, never written any more.
  static const keywords = 'keywords';

  /// The target: a category of the year's tree, or an account for a
  /// transfer. Exactly one is set.
  static const targetCategoryId = 'targetCategoryId';
  static const targetAccountId = 'targetAccountId';
}

/// A term written `re:…` is a regular expression.
const regexKeywordPrefix = 're:';

/// The word that joins the terms of a line, all of them required: written
/// in capitals between spaces, so that « et » in a shop name stays a word.
const andWord = 'ET';

final _andSeparator = RegExp(r'\s+ET\s+');

/// The form under which terms and texts are compared: lower case, without
/// accents, every run of spaces or line breaks one space.
String normalizeText(String text) => normalizeName(text.replaceAll(RegExp(r'\s+'), ' '));

/// One term of a line, ready to match a normalised text.
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

  /// Whether this term is in [normalized], a text from [normalizeText].
  bool matches(String normalized) => _regex?.hasMatch(normalized) ?? normalized.contains(_plain!);

  /// The form two terms are the same under.
  String get key => _regex == null ? _plain! : '$regexKeywordPrefix${_regex.pattern}';
}

/// One line of a rule: its terms, joined by [andWord], each required
/// anywhere in the text. A line without [andWord] is one term, matched as
/// a whole.
class RuleLine {
  /// Throws a [FormatException] for an invalid regular expression or a line
  /// without any term.
  factory RuleLine(String line) {
    final byKey = <String, Keyword>{};
    for (final part in line.trim().split(_andSeparator)) {
      if (part.trim().isEmpty) continue;
      final keyword = Keyword(part);
      byKey[keyword.key] = keyword;
    }
    if (byKey.isEmpty) throw const FormatException('empty line');
    return RuleLine._(line.trim(), byKey.values.toList());
  }

  RuleLine._(this.text, this.terms);

  final String text;

  /// Distinct terms: the same term twice counts once.
  final List<Keyword> terms;

  /// The number of terms: between rules, the line with the most wins.
  int get weight => terms.length;

  bool matches(String normalized) => terms.every((k) => k.matches(normalized));
}

/// Whether [line] can be a line of a rule: at least one term, and every
/// regular expression (`re:…`) valid.
bool isValidRuleLine(String line) {
  try {
    RuleLine(line);
    return true;
  } on FormatException {
    return false;
  }
}

/// The lines of [text] as typed in a form, one per line, empty ones left
/// out.
List<String> ruleLinesOf(String text) => [
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty) line.trim(),
];

/// A mapping rule of a year: when one of its lines matches the raw text of
/// a line to validate, it proposes its target, for the payment date.
class MappingRule extends Equatable {
  MappingRule({
    required this.id,
    required this.year,
    required List<String> lines,
    this.targetCategoryId,
    this.targetAccountId,
  }) : lines = List.unmodifiable(lines),
       _compiled = _compile(lines);

  final String id;
  final int year;

  /// As written, at least one.
  final List<String> lines;
  final String? targetCategoryId;
  final String? targetAccountId;

  /// The lines that compile; a rule received from another device with an
  /// invalid expression keeps its other lines.
  final List<RuleLine> _compiled;

  static List<RuleLine> _compile(List<String> lines) => [
    for (final line in lines)
      if (isValidRuleLine(line)) RuleLine(line),
  ];

  bool get isTransfer => targetAccountId != null;

  /// The weight of the rule for [normalized] (a text from [normalizeText]):
  /// the number of terms of its heaviest matching line, 0 when no line
  /// matches.
  int weightFor(String normalized) {
    var weight = 0;
    for (final line in _compiled) {
      if (line.weight > weight && line.matches(normalized)) weight = line.weight;
    }
    return weight;
  }

  bool matches(String normalized) => weightFor(normalized) > 0;

  /// What the rule proposes, compared between rules of equal weight: the
  /// same target is no conflict.
  (String?, String?) get result => (targetCategoryId, targetAccountId);

  @override
  List<Object?> get props => [id, year, lines, targetCategoryId, targetAccountId];
}

/// What the user enters to create or modify a rule.
class RuleDraft {
  const RuleDraft({required this.year, required this.lines, this.targetCategoryId, this.targetAccountId});

  factory RuleDraft.of(MappingRule rule) => RuleDraft(
    year: rule.year,
    lines: rule.lines,
    targetCategoryId: rule.targetCategoryId,
    targetAccountId: rule.targetAccountId,
  );

  final int year;
  final List<String> lines;
  final String? targetCategoryId;
  final String? targetAccountId;
}

String encodeRuleLines(List<String> lines) => jsonEncode(lines);

/// The strings of their JSON form, or null if it is not a list of strings.
List<String>? decodeRuleLines(Object? value) {
  if (value is! String) return null;
  try {
    final list = jsonDecode(value);
    if (list is! List || list.any((k) => k is! String)) return null;
    return list.cast<String>();
  } on FormatException {
    return null;
  }
}

/// The line that keywords written before lines existed, all required, read
/// as.
String legacyRuleLine(List<String> keywords) => [
  for (final k in keywords)
    if (k.trim().isNotEmpty) k.trim(),
].join(' $andWord ');

/// Identifier of the copy, in [year], of the rule [sourceId]: computed like
/// the copies of categories, which rules follow.
String copiedRuleId(String sourceId, int year) => derivedId('rule-copy/$sourceId/$year');

/// The line « Créer une règle » starts with for a transaction whose bank text is
/// [rawText] and whose description is [description]: always a keyword found
/// in that text as rules read it, so that the rule classifies at least that
/// transaction as long as this line is kept.
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
