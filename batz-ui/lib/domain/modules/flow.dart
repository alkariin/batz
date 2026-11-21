/// The flow diagram of a year: from the income, on the left, to the taxes,
/// the expenses and the savings, on the right, with the amounts of the «
/// Année » screen in the view shown. Computed when its screen opens, never
/// stored.
library;

import '../ledger/category.dart';
import '../ledger/ledger.dart';
import '../views/year_view.dart';
import 'salary.dart';
import 'settings.dart';

/// What a node of the diagram stands for.
enum FlowNodeKind {
  /// « Salaire brut »: the net received in the salary category plus the
  /// deductions of the sheet of the year.
  grossSalary,

  /// The salary category, net, when the diagram starts from the net.
  salary,

  /// A deduction of the salary sheet.
  deduction,

  /// The category of the taxes module.
  taxes,

  /// A top-level group, whole.
  group,

  /// A top-level group without the designated categories it holds.
  groupRest,

  /// « À classer » of a nature.
  toClassify,

  /// « Puisé dans la fortune »: expenses above income.
  fromWealth,

  /// « Épargne »: income above expenses.
  savings,
}

enum FlowSide { left, right }

/// A node: what it stands for, and its amount, positive.
class FlowNode {
  const FlowNode({
    required this.kind,
    required this.key,
    required this.side,
    required this.amount,
    required this.signed,
    this.category,
    this.without = const [],
    this.label,
    this.nature,
  });

  final FlowNodeKind kind;

  /// Stable within a diagram, for the screen.
  final String key;
  final FlowSide side;
  final int amount;

  /// The amount as it adds to the result of the view: positive for what
  /// comes in, negative for what goes out (a cost, a deduction, the
  /// savings).
  final int signed;

  /// The category (salary, taxes) or the top-level group.
  final Category? category;

  /// For [FlowNodeKind.groupRest], the categories taken out of the group.
  final List<Category> without;

  /// For a deduction, its label.
  final String? label;

  /// The nature its amount belongs to; null for the savings and what is
  /// taken from the wealth.
  final CategoryNature? nature;
}

/// A band from a node on the left to a node on the right.
class FlowLink {
  const FlowLink(this.from, this.to, this.amount);

  /// Indexes in [FlowDiagram.left] and [FlowDiagram.right].
  final int from;
  final int to;
  final int amount;
}

class FlowDiagram {
  FlowDiagram({
    required this.year,
    required this.kind,
    required this.left,
    required this.right,
    required this.links,
    required this.salaryCategory,
    required this.taxesCategory,
    required this.sheet,
    required this.unclassified,
  });

  final int year;
  final ViewKind kind;
  final List<FlowNode> left;
  final List<FlowNode> right;
  final List<FlowLink> links;

  /// The categories of the salary and the taxes modules in the tree of the
  /// year, null when the tree has no such name.
  final Category? salaryCategory;
  final Category? taxesCategory;

  /// The salary sheet of the year: the diagram starts from the gross when
  /// there is one and the salary category is found.
  final SalarySheet? sheet;

  /// « Non classé » of the view: not in the diagram, recalled by the screen.
  final int unclassified;

  bool get fromGross => left.any((n) => n.kind == FlowNodeKind.grossSalary);

  /// The net received plus the deductions, minus the gross entered: shown
  /// when it is not zero.
  int? get grossGap {
    if (!fromGross) return null;
    final gross = left.firstWhere((n) => n.kind == FlowNodeKind.grossSalary);
    return gross.signed - sheet!.gross;
  }

  int get leftTotal => left.fold(0, (sum, n) => sum + n.amount);
  int get rightTotal => right.fold(0, (sum, n) => sum + n.amount);
}

/// The diagram of [year] in the view [kind]; null when the year is not
/// shown (before the first tree).
FlowDiagram? flowDiagram(Ledger ledger, int year, ViewKind kind) {
  final view = ledger.views.of(year, kind);
  if (view == null) return null;
  final tree = view.tree;

  // What a category weighs in the total of its top-level group, its
  // redistribution lines included.
  int weight(String id) => view.categories[id]!.total + view.redistributedOf(id).total;

  var salary = ledger.moduleCategory(ModuleKind.salary, year);
  var taxes = ledger.moduleCategory(ModuleKind.taxes, year);
  // A category inside the other counts once, with the outer one.
  if (salary != null && taxes != null) {
    if (tree.subtreeOf(salary.id).contains(taxes.id)) {
      taxes = null;
    } else if (tree.subtreeOf(taxes.id).contains(salary.id)) {
      salary = null;
    }
  }
  final sheet = ledger.salarySheet(year);
  final fromGross = sheet != null && salary != null;

  final entries = <FlowNode>[];
  void add(
    FlowNodeKind kind,
    String key,
    int signed, {
    Category? category,
    List<Category> without = const [],
    String? label,
    CategoryNature? nature,
  }) {
    if (signed == 0) return;
    entries.add(
      FlowNode(
        kind: kind,
        key: key,
        side: signed > 0 ? FlowSide.left : FlowSide.right,
        amount: signed.abs(),
        signed: signed,
        category: category,
        without: without,
        label: label,
        nature: nature,
      ),
    );
  }

  if (salary != null) {
    final nature = tree.natureOf(salary.id);
    if (fromGross) {
      add(
        FlowNodeKind.grossSalary,
        'gross',
        weight(salary.id) + sheet.deductionsTotal,
        category: salary,
        nature: nature,
      );
      for (final d in sheet.deductions) {
        add(FlowNodeKind.deduction, 'deduction-${d.id}', -d.amount, label: d.label, nature: nature);
      }
    } else {
      add(FlowNodeKind.salary, 'salary', weight(salary.id), category: salary, nature: nature);
    }
  }
  if (taxes != null) {
    add(FlowNodeKind.taxes, 'taxes', weight(taxes.id), category: taxes, nature: tree.natureOf(taxes.id));
  }
  final designated = [?salary, ?taxes];
  for (final root in tree.roots) {
    if (designated.any((c) => c.id == root.id)) continue;
    final inside = [
      for (final c in designated)
        if (tree.rootOf(c.id).id == root.id) c,
    ];
    final rest = inside.fold(view.categories[root.id]!.total, (sum, c) => sum - weight(c.id));
    add(
      inside.isEmpty ? FlowNodeKind.group : FlowNodeKind.groupRest,
      'group-${root.id}',
      rest,
      category: root,
      without: inside,
      nature: root.nature,
    );
  }
  for (final nature in CategoryNature.values) {
    add(FlowNodeKind.toClassify, 'toClassify-${nature.name}', view.toClassify[nature]!.total, nature: nature);
  }

  // The balance of the view: savings, or what is taken from the wealth.
  final savings = view.savings.total;
  final left = [
    for (final n in entries)
      if (n.side == FlowSide.left) n,
  ];
  final right = [
    for (final n in entries)
      if (n.side == FlowSide.right) n,
  ];
  if (savings > 0) {
    right.add(
      FlowNode(kind: FlowNodeKind.savings, key: 'savings', side: FlowSide.right, amount: savings, signed: -savings),
    );
  } else if (savings < 0) {
    left.add(
      FlowNode(
        kind: FlowNodeKind.fromWealth,
        key: 'fromWealth',
        side: FlowSide.left,
        amount: -savings,
        signed: -savings,
      ),
    );
  }

  return FlowDiagram(
    year: year,
    kind: kind,
    left: left,
    right: right,
    links: _links(left, right),
    salaryCategory: salary,
    taxesCategory: taxes,
    sheet: sheet,
    unclassified: view.unclassified.total,
  );
}

/// The bands: both columns stacked in their order, each part of the left
/// stack flows to the part of the right stack at the same height.
List<FlowLink> _links(List<FlowNode> left, List<FlowNode> right) {
  final links = <FlowLink>[];
  var i = 0, j = 0;
  var leftUsed = 0, rightUsed = 0;
  while (i < left.length && j < right.length) {
    final amount = (left[i].amount - leftUsed) < (right[j].amount - rightUsed)
        ? left[i].amount - leftUsed
        : right[j].amount - rightUsed;
    if (amount > 0) links.add(FlowLink(i, j, amount));
    leftUsed += amount;
    rightUsed += amount;
    if (leftUsed == left[i].amount) {
      i++;
      leftUsed = 0;
    }
    if (rightUsed == right[j].amount) {
      j++;
      rightUsed = 0;
    }
  }
  return links;
}
