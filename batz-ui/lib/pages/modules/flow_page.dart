import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/modules/flow.dart';
import '../../domain/modules/settings.dart';
import '../../domain/views/year_view.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';
import '../ledger_cubit.dart';
import '../ledger_texts.dart';

/// The name of [node] on the screen.
String flowNodeName(AppLocalizations l, FlowNode node) => switch (node.kind) {
  FlowNodeKind.grossSalary => l.flowGross,
  FlowNodeKind.deduction => node.label!,
  FlowNodeKind.groupRest || FlowNodeKind.subcategoryRest => l.flowGroupWithout(
    node.category!.name,
    node.without.map((c) => c.name).join(l.flowAnd),
  ),
  FlowNodeKind.direct => l.flowDirect(node.category!.name),
  FlowNodeKind.toClassify => l.yearToClassifyNature(natureText(l, node.nature!)),
  FlowNodeKind.fromWealth => l.flowFromWealth,
  FlowNodeKind.savings => l.yearSavings,
  FlowNodeKind.salary || FlowNodeKind.taxes || FlowNodeKind.group || FlowNodeKind.subcategory => node.category!.name,
};

/// The flow diagram of a year, opened from « Année » with its year and
/// its view, which it can switch: bands from the income on the left to
/// the taxes, the expenses and the savings on the right, then from each
/// group of expenses to its subcategories, a column per level, each band
/// as thick as its amount; the drawing scrolls sideways when the screen is
/// too narrow. Then the list of the nodes, the subcategories indented.
class FlowPage extends StatefulWidget {
  const FlowPage({super.key, required this.year, required this.initialKind});

  final int year;
  final ViewKind initialKind;

  @override
  State<FlowPage> createState() => _FlowPageState();
}

class _FlowPageState extends State<FlowPage> {
  late ViewKind _kind = widget.initialKind;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ledger = context.watch<LedgerCubit>().state.ledger;
    final diagram = flowDiagram(ledger, widget.year, _kind);
    final notes = <String>[];
    if (diagram != null) {
      if (diagram.fromGross) {
        notes.add(l.flowFromGross('${widget.year}'));
      } else if (diagram.salaryCategory == null) {
        notes.add(l.flowNoSalary(ledger.moduleCategoryName(ModuleKind.salary), '${widget.year}'));
      } else {
        notes.add(l.flowFromNet('${widget.year}'));
      }
    }
    final gap = diagram?.grossGap;
    return Scaffold(
      appBar: AppBar(title: Text(l.flowTitle('${widget.year}'))),
      body: ListView(
        key: const Key('flowList'),
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<ViewKind>(
              key: const Key('flowKind'),
              segments: [
                ButtonSegment(value: ViewKind.cash, label: Text(l.yearViewCash)),
                ButtonSegment(value: ViewKind.economic, label: Text(l.yearViewEconomic)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.single),
            ),
          ),
          const SizedBox(height: 8),
          for (final note in notes) Text(note, style: theme.textTheme.bodySmall),
          if (gap != null && gap != 0)
            Text(
              l.flowGrossGap(formatAmount(gap)),
              key: const Key('flowGrossGap'),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          if (diagram != null && diagram.unclassified != 0)
            Text(
              l.flowUnclassified(formatAmount(diagram.unclassified)),
              key: const Key('flowUnclassified'),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 12),
          if (diagram == null || diagram.leftTotal == 0)
            Text(l.flowEmpty)
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final layout = _FlowLayout(diagram, availableWidth: constraints.maxWidth);
                final chart = SizedBox(
                  key: const Key('flowChart'),
                  height: layout.height,
                  width: layout.width,
                  child: CustomPaint(
                    painter: _FlowPainter(
                      diagram: diagram,
                      layout: layout,
                      names: [
                        for (final column in diagram.columns)
                          for (final n in column) flowNodeName(l, n),
                      ],
                      colors: theme.colorScheme,
                      textStyle: theme.textTheme.bodySmall!,
                      direction: Directionality.of(context),
                    ),
                  ),
                );
                // Readable on a desktop: the drawing keeps a moderate width;
                // on a phone, its columns keep theirs and it scrolls.
                return layout.width > constraints.maxWidth
                    ? SingleChildScrollView(
                        key: const Key('flowScroll'),
                        scrollDirection: Axis.horizontal,
                        child: chart,
                      )
                    : Align(alignment: Alignment.centerLeft, child: chart);
              },
            ),
            const SizedBox(height: 16),
            _NodeList(title: l.flowLeft, nodes: diagram.left, total: diagram.leftTotal, side: 'left'),
            const SizedBox(height: 8),
            _NodeList(
              title: l.flowRight,
              nodes: diagram.right,
              total: diagram.rightTotal,
              side: 'right',
              details: diagram.columns.skip(2).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// The nodes of one side and their amounts, under the drawing; on the
/// right, each node followed by its subcategories, indented level by level.
class _NodeList extends StatelessWidget {
  const _NodeList({
    required this.title,
    required this.nodes,
    required this.total,
    required this.side,
    this.details = const [],
  });

  final String title;
  final List<FlowNode> nodes;
  final int total;
  final String side;

  /// The columns of subcategories, after [nodes].
  final List<List<FlowNode>> details;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rows = <Widget>[];
    void add(FlowNode node, int level, int index) {
      rows.add(
        Padding(
          key: ValueKey('flowNode-$side-${node.key}'),
          padding: EdgeInsets.only(left: 16.0 * level, top: 2, bottom: 2),
          child: Row(
            children: [
              Expanded(child: Text(flowNodeName(l, node), style: level == 0 ? null : theme.textTheme.bodySmall)),
              Text(
                formatAmount(node.reverse ? -node.amount : node.amount),
                key: ValueKey('flowAmount-$side-${node.key}'),
                style: level == 0 ? null : theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
      if (level < details.length) {
        for (final (i, child) in details[level].indexed) {
          if (child.parent == index) add(child, level + 1, i);
        }
      }
    }

    for (final (i, node) in nodes.indexed) {
      add(node, 0, i);
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            ...rows,
            const Divider(),
            Text(
              l.flowTotal(formatAmount(total)),
              key: ValueKey('flowTotal-$side'),
              textAlign: TextAlign.right,
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Where everything goes: the width and height of the drawing, the scale
/// (pixels per cent), the x of each column, the top of each bar and of
/// each label. The first two columns are stacked as before; a column of
/// subcategories places the children of each node next to it, pushed down
/// when the children of the node above need the room.
class _FlowLayout {
  _FlowLayout(this.diagram, {required double availableWidth}) {
    final columns = diagram.columns;
    final count = math.max(diagram.left.length, diagram.right.length);
    final base = math.max(260.0, 46.0 * count);
    scale = (base - gap * (count - 1)) / math.max(diagram.leftTotal, 1);
    final spaces = columns.length - 1;
    width = spaces == 1
        ? math.min(availableWidth, 900)
        : (availableWidth >= _wide * spaces + bar
              ? _wide * spaces + bar
              : math.max(availableWidth, _narrow * spaces + bar));
    spacing = (width - bar) / spaces;
    var bottom = base;
    for (final (c, column) in columns.indexed) {
      final columnTops = <double>[];
      var cursor = 0.0;
      int? lastParent;
      for (final n in column) {
        if (c >= 2 && n.parent != lastParent) {
          cursor = math.max(cursor, tops[c - 1][n.parent!]);
          lastParent = n.parent;
        }
        columnTops.add(cursor);
        cursor += heightOf(n) + gap;
      }
      tops.add(columnTops);
      bottom = math.max(bottom, cursor - gap);
      final columnLabels = <double>[];
      var next = 0.0;
      for (final (i, n) in column.indexed) {
        final top = math.max(columnTops[i] + heightOf(n) / 2 - labelHeight / 2, next);
        columnLabels.add(top);
        next = top + labelHeight;
      }
      labels.add(columnLabels);
      bottom = math.max(bottom, next);
    }
    height = bottom;
  }

  static const bar = 10.0, gap = 6.0, labelHeight = 30.0;
  static const _wide = 260.0, _narrow = 190.0;

  final FlowDiagram diagram;
  late final double scale;
  late final double width;
  late final double height;
  late final double spacing;
  final tops = <List<double>>[];
  final labels = <List<double>>[];

  double heightOf(FlowNode n) => math.max(n.amount * scale, 1);

  /// The left edge of the bars of column [c]: the last one at the right
  /// edge of the drawing.
  double xOf(int c) => c == diagram.columns.length - 1 ? width - bar : c * spacing;

  /// The room for the labels of column [c]: the last two columns share
  /// their gap, the others have it to themselves.
  double labelWidth(int c) {
    final last = diagram.columns.length - 1;
    return c >= last - 1 ? spacing / 2 - bar - 8 : spacing - bar - 16;
  }
}

/// The columns of bars, each as tall as its amount, and the bands between
/// them; each node carries its name and its amount.
class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.diagram,
    required this.layout,
    required this.names,
    required this.colors,
    required this.textStyle,
    required this.direction,
  });

  final FlowDiagram diagram;
  final _FlowLayout layout;
  final List<String> names;
  final ColorScheme colors;
  final TextStyle textStyle;
  final TextDirection direction;

  /// A colour per node of the right, its subcategories taking its colour:
  /// hues turning from the primary one.
  Color _colour(int index) {
    final base = HSLColor.fromColor(colors.primary);
    return base.withHue((base.hue + 47.0 * index) % 360).toColor();
  }

  Color _nodeColour(int column, int index) {
    if (column == 0) return colors.primary;
    final n = diagram.columns[column][index];
    if (n.reverse) return colors.outline;
    return column == 1 ? _colour(index) : _colour(n.branch!).withValues(alpha: 0.75);
  }

  void _band(Canvas canvas, double x0, double y0, double x1, double y1, double thickness, Color colour) {
    final middle = (x0 + x1) / 2;
    final path = Path()
      ..moveTo(x0, y0)
      ..cubicTo(middle, y0, middle, y1, x1, y1)
      ..lineTo(x1, y1 + thickness)
      ..cubicTo(middle, y1 + thickness, middle, y0 + thickness, x0, y0 + thickness)
      ..close();
    canvas.drawPath(path, Paint()..color = colour.withValues(alpha: 0.35));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final columns = diagram.columns, scale = layout.scale, bar = _FlowLayout.bar;
    for (final (c, links) in diagram.bands.indexed) {
      final from = columns[c], to = columns[c + 1];
      // A parent with a subcategory in gain gives its others less than
      // their own amount: its bands fit its bar.
      final out = List.filled(from.length, 0);
      for (final link in links) {
        out[link.from] += link.amount;
      }
      final fromUsed = List.filled(from.length, 0.0), toUsed = List.filled(to.length, 0.0);
      final x0 = layout.xOf(c) + bar, x1 = layout.xOf(c + 1);
      for (final link in links) {
        final parent = from[link.from];
        final factor = c == 0 || out[link.from] <= parent.amount ? 1.0 : parent.amount / out[link.from];
        final thickness = link.amount * scale * factor;
        final y0 = layout.tops[c][link.from] + fromUsed[link.from];
        final y1 = layout.tops[c + 1][link.to] + toUsed[link.to];
        fromUsed[link.from] += thickness;
        toUsed[link.to] += thickness;
        final colour = c == 0 ? _colour(link.to) : _colour(to[link.to].branch!);
        _band(canvas, x0, y0, x1, y1, thickness, colour);
      }
    }
    var offset = 0;
    for (final (c, column) in columns.indexed) {
      for (final (i, n) in column.indexed) {
        canvas.drawRect(
          Rect.fromLTWH(layout.xOf(c), layout.tops[c][i], bar, layout.heightOf(n)),
          Paint()..color = _nodeColour(c, i),
        );
      }
      _labels(canvas, c, offset);
      offset += column.length;
    }
  }

  /// The name and amount of each node beside its bar: to its right, but to
  /// its left in the last column.
  void _labels(Canvas canvas, int c, int offset) {
    final nodes = diagram.columns[c];
    final alignRight = c == diagram.columns.length - 1;
    final bar = _FlowLayout.bar;
    for (final (i, n) in nodes.indexed) {
      final painter = TextPainter(
        text: TextSpan(
          style: textStyle.copyWith(color: colors.onSurface),
          children: [
            TextSpan(
              text: '${names[offset + i]}\n',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: formatAmount(n.reverse ? -n.amount : n.amount)),
          ],
        ),
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        textDirection: direction,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: math.max(layout.labelWidth(c), 40));
      final x = alignRight ? layout.xOf(c) - 6 - painter.width : layout.xOf(c) + bar + 6;
      final top = layout.labels[c][i];
      final box = Rect.fromLTWH(x - 3, top, painter.width + 6, painter.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(4)),
        Paint()..color = colors.surface.withValues(alpha: 0.85),
      );
      painter.paint(canvas, Offset(x, top));
    }
  }

  @override
  bool shouldRepaint(_FlowPainter old) =>
      old.diagram != diagram || old.colors != colors || old.textStyle != textStyle || !_same(old.names, names);

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
