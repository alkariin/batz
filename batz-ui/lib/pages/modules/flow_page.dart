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
  FlowNodeKind.groupRest => l.flowGroupWithout(node.category!.name, node.without.map((c) => c.name).join(l.flowAnd)),
  FlowNodeKind.toClassify => l.yearToClassifyNature(natureText(l, node.nature!)),
  FlowNodeKind.fromWealth => l.flowFromWealth,
  FlowNodeKind.savings => l.yearSavings,
  FlowNodeKind.salary || FlowNodeKind.taxes || FlowNodeKind.group => node.category!.name,
};

/// The flow diagram of a year, opened from « Année » with its year and
/// its view, which it can switch: bands from the income on the left to
/// the taxes, the expenses and the savings on the right, each as thick as
/// its amount, then the list of the nodes.
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
                // Readable on a desktop: the drawing keeps a moderate width.
                final count = math.max(diagram.left.length, diagram.right.length);
                final height = math.max(260.0, 46.0 * count);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    key: const Key('flowChart'),
                    height: height,
                    width: math.min(constraints.maxWidth, 900),
                    child: CustomPaint(
                      painter: _FlowPainter(
                        diagram: diagram,
                        names: [
                          for (final n in [...diagram.left, ...diagram.right]) flowNodeName(l, n),
                        ],
                        colors: theme.colorScheme,
                        textStyle: theme.textTheme.bodySmall!,
                        direction: Directionality.of(context),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _NodeList(title: l.flowLeft, nodes: diagram.left, total: diagram.leftTotal, side: 'left'),
            const SizedBox(height: 8),
            _NodeList(title: l.flowRight, nodes: diagram.right, total: diagram.rightTotal, side: 'right'),
          ],
        ],
      ),
    );
  }
}

/// The nodes of one side and their amounts, under the drawing.
class _NodeList extends StatelessWidget {
  const _NodeList({required this.title, required this.nodes, required this.total, required this.side});

  final String title;
  final List<FlowNode> nodes;
  final int total;
  final String side;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            for (final node in nodes)
              Padding(
                key: ValueKey('flowNode-$side-${node.key}'),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(flowNodeName(l, node))),
                    Text(formatAmount(node.amount), key: ValueKey('flowAmount-$side-${node.key}')),
                  ],
                ),
              ),
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

/// Two columns of bars, each as tall as its amount, and the bands between
/// them; each node carries its name and its amount.
class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.diagram,
    required this.names,
    required this.colors,
    required this.textStyle,
    required this.direction,
  });

  final FlowDiagram diagram;
  final List<String> names;
  final ColorScheme colors;
  final TextStyle textStyle;
  final TextDirection direction;

  static const _bar = 10.0, _gap = 6.0, _labelHeight = 30.0;

  /// A colour per node of the right: hues turning from the primary one.
  Color _colour(int index) {
    final base = HSLColor.fromColor(colors.primary);
    return base.withHue((base.hue + 47.0 * index) % 360).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final left = diagram.left, right = diagram.right;
    final total = math.max(diagram.leftTotal, 1);
    final scale = (size.height - _gap * (math.max(left.length, right.length) - 1)) / total;
    List<double> tops(List<FlowNode> nodes) {
      var y = 0.0;
      return [
        for (final n in nodes)
          () {
            final top = y;
            y += n.amount * scale + _gap;
            return top;
          }(),
      ];
    }

    final leftTops = tops(left), rightTops = tops(right);
    final leftUsed = List.filled(left.length, 0.0), rightUsed = List.filled(right.length, 0.0);
    final x0 = _bar, x1 = size.width - _bar;
    for (final link in diagram.links) {
      final thickness = link.amount * scale;
      final y0 = leftTops[link.from] + leftUsed[link.from];
      final y1 = rightTops[link.to] + rightUsed[link.to];
      leftUsed[link.from] += thickness;
      rightUsed[link.to] += thickness;
      final middle = (x0 + x1) / 2;
      final path = Path()
        ..moveTo(x0, y0)
        ..cubicTo(middle, y0, middle, y1, x1, y1)
        ..lineTo(x1, y1 + thickness)
        ..cubicTo(middle, y1 + thickness, middle, y0 + thickness, x0, y0 + thickness)
        ..close();
      canvas.drawPath(path, Paint()..color = _colour(link.to).withValues(alpha: 0.35));
    }
    for (final (i, n) in left.indexed) {
      canvas.drawRect(
        Rect.fromLTWH(0, leftTops[i], _bar, math.max(n.amount * scale, 1)),
        Paint()..color = colors.primary,
      );
    }
    for (final (j, n) in right.indexed) {
      canvas.drawRect(
        Rect.fromLTWH(x1, rightTops[j], _bar, math.max(n.amount * scale, 1)),
        Paint()..color = _colour(j),
      );
    }
    _labels(canvas, size, left, leftTops, scale, 0, alignRight: false);
    _labels(canvas, size, right, rightTops, scale, left.length, alignRight: true);
  }

  /// The name and amount of each node beside its bar, moved down when they
  /// would overlap.
  void _labels(
    Canvas canvas,
    Size size,
    List<FlowNode> nodes,
    List<double> tops,
    double scale,
    int offset, {
    required bool alignRight,
  }) {
    final width = size.width / 2 - _bar - 8;
    var next = 0.0;
    for (final (i, n) in nodes.indexed) {
      final center = tops[i] + n.amount * scale / 2;
      final top = math.min(math.max(center - _labelHeight / 2, next), size.height - _labelHeight);
      next = top + _labelHeight;
      final painter = TextPainter(
        text: TextSpan(
          style: textStyle.copyWith(color: colors.onSurface),
          children: [
            TextSpan(
              text: '${names[offset + i]}\n',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: formatAmount(n.amount)),
          ],
        ),
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        textDirection: direction,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: width);
      final x = alignRight ? size.width - _bar - 6 - painter.width : _bar + 6;
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
