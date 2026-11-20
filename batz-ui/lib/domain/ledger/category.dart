import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

/// Nature of a top-level group (specification, 4.1); every category below it
/// inherits it.
enum CategoryNature { income, expense }

/// Journal entity and fields of a category.
abstract final class CategoryFields {
  static const entity = 'category';
  static const year = 'year';
  static const name = 'name';
  static const parentId = 'parentId';
  static const nature = 'nature';
  static const position = 'position';
}

class Category extends Equatable {
  const Category({
    required this.id,
    required this.year,
    required this.name,
    this.parentId,
    this.nature,
    this.position = 0,
  });

  final String id;
  final int year;
  final String name;

  /// Null for a top-level group.
  final String? parentId;

  /// Stored on top-level groups only; see [CategoryTree.natureOf].
  final CategoryNature? nature;

  /// Order among siblings.
  final int position;

  bool get isTopLevel => parentId == null;

  @override
  List<Object?> get props => [id, year, name, parentId, nature, position];
}

/// The form under which two category names are compared (decision H1 of
/// phase 1): lower case, without accents, without surrounding spaces.
/// « Impôts » and « impots » are the same name.
String normalizeName(String name) {
  final buffer = StringBuffer();
  for (final rune in name.trim().toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_unaccented[char] ?? char);
  }
  return buffer.toString();
}

final Map<String, String> _unaccented = () {
  const groups = {
    'a': 'àáâãäåāăą',
    'ae': 'æ',
    'c': 'çćĉċč',
    'd': 'ďđ',
    'e': 'èéêëēĕėęě',
    'g': 'ĝğġģ',
    'h': 'ĥħ',
    'i': 'ìíîïĩīĭįı',
    'j': 'ĵ',
    'k': 'ķ',
    'l': 'ĺļľŀł',
    'n': 'ñńņňŉ',
    'o': 'òóôõöøōŏő',
    'oe': 'œ',
    'r': 'ŕŗř',
    's': 'śŝşšß',
    't': 'ţťŧ',
    'u': 'ùúûüũūŭůűų',
    'w': 'ŵ',
    'y': 'ýÿŷ',
    'z': 'źżž',
  };
  return {
    for (final group in groups.entries)
      for (final char in group.value.split('')) char: char == 'ß' ? 'ss' : group.key,
  };
}();

/// Default names of the two groups a first tree starts with (decision H4).
const defaultGroupNames = {CategoryNature.income: 'Revenus', CategoryNature.expense: 'Dépenses'};

/// Identifier of the copy, in [year], of the category [sourceId] (design
/// rule 4 of phase 1): computed, so that two devices copying the same tree
/// offline write the same records instead of two trees.
String copiedCategoryId(String sourceId, int year) => _derivedId('category-copy/$sourceId/$year');

/// Identifier of a default group of [year] (decision H4), computed for the
/// same reason as [copiedCategoryId].
String defaultGroupId(int year, CategoryNature nature) => _derivedId('category-default/$year/${nature.name}');

/// A name-based UUID (version 5 layout) from a SHA-256 digest.
String _derivedId(String name) {
  final bytes = sha256.convert(utf8.encode('batz/$name')).bytes.sublist(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// The category tree of one year.
class CategoryTree {
  CategoryTree._(this.year, this.byId) {
    for (final category in byId.values) {
      (_children[category.parentId] ??= []).add(category);
    }
    for (final siblings in _children.values) {
      siblings.sort(_siblingOrder);
    }
  }

  /// Builds the trees of [categories], one per year. A category is kept only
  /// if its chain of parents, in the same year, reaches a top-level group
  /// that has a nature, without a loop. The others are incomplete (their
  /// parent may not have arrived yet) and are ignored (design rule 2).
  static Map<int, CategoryTree> build(Iterable<Category> categories) {
    final byId = {for (final c in categories) c.id: c};
    final valid = <String, bool>{};
    bool check(Category category) {
      final path = <String>[];
      var current = category;
      bool result;
      while (true) {
        final known = valid[current.id];
        if (known != null) {
          result = known;
          break;
        }
        if (path.contains(current.id)) {
          result = false; // a loop
          break;
        }
        path.add(current.id);
        if (current.parentId == null) {
          result = current.nature != null;
          break;
        }
        final parent = byId[current.parentId];
        if (parent == null || parent.year != current.year) {
          result = false;
          break;
        }
        current = parent;
      }
      for (final id in path) {
        valid[id] = result;
      }
      return result;
    }

    final byYear = <int, Map<String, Category>>{};
    for (final category in byId.values) {
      if (check(category)) (byYear[category.year] ??= {})[category.id] = category;
    }
    return {for (final entry in byYear.entries) entry.key: CategoryTree._(entry.key, entry.value)};
  }

  /// A tree made of [categories], assumed consistent (see [build]).
  factory CategoryTree.of(int year, Iterable<Category> categories) =>
      CategoryTree._(year, {for (final c in categories) c.id: c});

  static int _siblingOrder(Category a, Category b) {
    if (a.position != b.position) return a.position.compareTo(b.position);
    final byName = normalizeName(a.name).compareTo(normalizeName(b.name));
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  final int year;
  final Map<String, Category> byId;
  final _children = <String?, List<Category>>{};

  List<Category> get roots => List.unmodifiable(_children[null] ?? const []);

  List<Category> childrenOf(String id) => List.unmodifiable(_children[id] ?? const []);

  bool hasChildren(String id) => _children[id]?.isNotEmpty ?? false;

  /// The top-level group of [id].
  Category rootOf(String id) {
    var current = byId[id]!;
    while (current.parentId != null) {
      current = byId[current.parentId]!;
    }
    return current;
  }

  /// The nature of [id], inherited from its top-level group.
  CategoryNature natureOf(String id) => rootOf(id).nature!;

  int depthOf(String id) {
    var depth = 0;
    for (var current = byId[id]!; current.parentId != null; current = byId[current.parentId]!) {
      depth++;
    }
    return depth;
  }

  /// Whether a transaction may be classified in [id] (decision H2): only in a
  /// category without children, and never in a top-level group, which only
  /// adds up its children.
  bool canHoldTransactions(String id) {
    final category = byId[id];
    return category != null && !category.isTopLevel && !hasChildren(id);
  }

  /// [id] and everything below it.
  Set<String> subtreeOf(String id) {
    final result = <String>{id};
    for (final child in _children[id] ?? const <Category>[]) {
      result.addAll(subtreeOf(child.id));
    }
    return result;
  }

  /// Every category, parents before their children, siblings in order.
  List<Category> get ordered {
    final result = <Category>[];
    void visit(Category category) {
      result.add(category);
      for (final child in _children[category.id] ?? const <Category>[]) {
        visit(child);
      }
    }

    for (final root in roots) {
      visit(root);
    }
    return result;
  }

  /// The categories a transaction may be classified in, in tree order.
  List<Category> get assignable => [
    for (final c in ordered)
      if (canHoldTransactions(c.id)) c,
  ];

  /// The category of this year whose name is [name] (decision H1).
  Category? named(String name) {
    final normalized = normalizeName(name);
    for (final category in byId.values) {
      if (normalizeName(category.name) == normalized) return category;
    }
    return null;
  }
}
