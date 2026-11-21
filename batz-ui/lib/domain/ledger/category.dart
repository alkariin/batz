import 'package:equatable/equatable.dart';

import '../ids.dart';

/// Nature of a top-level group; every category below it inherits it.
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

/// The form under which two category names are compared: lower case,
/// without accents, without surrounding spaces. « Impôts » and « impots
/// » are the same name.
String normalizeName(String name) {
  final buffer = StringBuffer();
  for (final rune in name.trim().toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_unaccented[char] ?? char);
  }
  return buffer.toString();
}

/// [text] with its accented Latin letters replaced by their base letter,
/// in lower case; every other character is kept as it is, case included.
/// Regular expressions of rules go through it: lower-casing a whole
/// expression would turn `\S` into `\s`.
String stripAccents(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_unaccented[char.toLowerCase()] ?? char);
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

/// Default names of the two groups a first tree starts with.
const defaultGroupNames = {CategoryNature.income: 'Revenus', CategoryNature.expense: 'Dépenses'};

/// Identifier of the copy, in [year], of the category [sourceId]:
/// computed, so that two devices copying the same tree offline write the
/// same records instead of two trees.
String copiedCategoryId(String sourceId, int year) => derivedId('category-copy/$sourceId/$year');

/// Identifier of a default group of [year], computed for the same reason
/// as [copiedCategoryId].
String defaultGroupId(int year, CategoryNature nature) => derivedId('category-default/$year/${nature.name}');

/// Why a category is detached from the tree of its year.
enum DetachReason {
  /// It is part of a loop of parents: two moves made at the same time on
  /// two devices can produce one.
  loop,

  /// Its parent is deleted, or has not arrived yet.
  missingParent,

  /// Its parent belongs to another year.
  parentInOtherYear,

  /// A top-level group without a nature.
  groupWithoutNature,

  /// One of its ancestors is detached for one of the reasons above; it comes
  /// back with that ancestor.
  detachedAncestor,
}

/// A category whose chain of parents does not reach, within its year, a
/// top-level group with a nature.
class DetachedCategory extends Equatable {
  const DetachedCategory(this.category, this.reason);

  final Category category;
  final DetachReason reason;

  /// Whether the category is where the chain breaks, as opposed to one that
  /// is only below such a category: those are the ones to move.
  bool get isHead => reason != DetachReason.detachedAncestor;

  @override
  List<Object?> get props => [category, reason];
}

/// The trees of every year, and the categories that are not part of them.
class CategoryForest {
  CategoryForest._(this.trees, this.detached);

  /// Sorts [categories] into the tree of their year and the detached ones.
  ///
  /// A category is part of its year's tree if its chain of parents, in the same
  /// year, reaches a top-level group that has a nature, without a loop. The
  /// others are detached: they are never lost, the categories screen lists them
  /// so that they can be moved back.
  factory CategoryForest.build(Iterable<Category> categories) {
    final byId = {for (final c in categories) c.id: c};
    // Null for a category of a tree; the reason for a detached one.
    final status = <String, DetachReason?>{};
    for (final start in byId.values) {
      final path = <Category>[];
      final onPath = <String, int>{};
      var current = start;
      DetachReason? below;
      while (true) {
        if (status.containsKey(current.id)) {
          below = status[current.id] == null ? null : DetachReason.detachedAncestor;
          break;
        }
        final index = onPath[current.id];
        if (index != null) {
          for (final member in path.sublist(index)) {
            status[member.id] = DetachReason.loop;
          }
          path.removeRange(index, path.length);
          below = DetachReason.detachedAncestor;
          break;
        }
        onPath[current.id] = path.length;
        path.add(current);
        final parent = current.parentId == null ? null : byId[current.parentId];
        final DetachReason? own;
        if (current.parentId == null) {
          own = current.nature == null ? DetachReason.groupWithoutNature : null;
        } else if (parent == null) {
          own = DetachReason.missingParent;
        } else if (parent.year != current.year) {
          own = DetachReason.parentInOtherYear;
        } else {
          current = parent;
          continue;
        }
        path.removeLast();
        status[current.id] = own;
        below = own == null ? null : DetachReason.detachedAncestor;
        break;
      }
      for (final category in path) {
        status[category.id] = below;
      }
    }

    final byYear = <int, Map<String, Category>>{};
    final detached = <String, DetachedCategory>{};
    for (final category in byId.values) {
      final reason = status[category.id];
      if (reason == null) {
        (byYear[category.year] ??= {})[category.id] = category;
      } else {
        detached[category.id] = DetachedCategory(category, reason);
      }
    }
    return CategoryForest._({
      for (final entry in byYear.entries) entry.key: CategoryTree._(entry.key, entry.value),
    }, detached);
  }

  /// The tree of each year that has at least one category attached to it.
  final Map<int, CategoryTree> trees;

  /// Every detached category, by identifier.
  final Map<String, DetachedCategory> detached;

  /// The detached categories of [year] where the chain breaks, by name: the
  /// ones the categories screen offers to move.
  List<DetachedCategory> detachedHeads(int year) => [
    for (final d in detached.values)
      if (d.category.year == year && d.isHead) d,
  ]..sort((a, b) => CategoryTree._siblingOrder(a.category, b.category));

  /// The detached categories directly below [id], in sibling order; loop
  /// members are listed as heads, never as children.
  List<Category> detachedChildrenOf(String id) => [
    for (final d in detached.values)
      if (d.category.parentId == id && !d.isHead) d.category,
  ]..sort(CategoryTree._siblingOrder);

  /// Years that have detached categories to move, in increasing order.
  List<int> get yearsWithDetached => {
    for (final d in detached.values)
      if (d.isHead) d.category.year,
  }.toList()..sort();
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

  /// Builds the trees of [categories], one per year, leaving out the
  /// detached categories (see [CategoryForest.build]).
  static Map<int, CategoryTree> build(Iterable<Category> categories) => CategoryForest.build(categories).trees;

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

  /// Whether a transaction may be classified in [id]: only in a category
  /// without children, and never in a top-level group, which only adds up its
  /// children.
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

  /// The category of this year whose name is [name].
  Category? named(String name) {
    final normalized = normalizeName(name);
    for (final category in byId.values) {
      if (normalizeName(category.name) == normalized) return category;
    }
    return null;
  }
}
