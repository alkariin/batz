import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../ids.dart';
import '../period_model.dart';
import 'category.dart';

/// Journal entity and fields of a mapping rule of a year (specification,
/// 4.5).
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

  /// What the rule proposes, compared between rules of equal weight
  /// (decision H5): the same target and the same period model are no
  /// conflict.
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
/// the copies of categories, which rules follow (step 3.4).
String copiedRuleId(String sourceId, int year) => derivedId('rule-copy/$sourceId/$year');
