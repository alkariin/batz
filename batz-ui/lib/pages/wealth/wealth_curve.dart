import 'package:flutter/material.dart';

import '../../domain/views/wealth.dart';
import '../../helpers/formats.dart';
import '../../l10n/app_localizations.dart';

/// `MM.YYYY`.
String monthLabel(int year, int month) => '${month.toString().padLeft(2, '0')}.$year';

/// The monthly curve of the wealth, drawn by the app: a line through the
/// end of each month. Touching or dragging along it shows the month nearest
/// and its amount; the last month is shown first.
class WealthCurve extends StatefulWidget {
  const WealthCurve({super.key, required this.months});

  final List<MonthWealth> months;

  @override
  State<WealthCurve> createState() => _WealthCurveState();
}

class _WealthCurveState extends State<WealthCurve> {
  int? _selected;

  void _select(double x, double width) {
    final count = widget.months.length;
    if (count == 0) return;
    final index = count == 1 ? 0 : (x / width * (count - 1)).round().clamp(0, count - 1);
    if (index != _selected) setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final months = widget.months;
    final index = (_selected ?? months.length - 1).clamp(0, months.length - 1);
    final point = months[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.wealthCurvePoint(monthLabel(point.year, point.month), formatAmount(point.amount)),
          key: const Key('wealthCurvePoint'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              key: const Key('wealthCurve'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _select(details.localPosition.dx, constraints.maxWidth),
              onHorizontalDragUpdate: (details) => _select(details.localPosition.dx, constraints.maxWidth),
              child: CustomPaint(
                size: Size(constraints.maxWidth, 180),
                painter: _CurvePainter(
                  amounts: [for (final m in months) m.amount],
                  selected: index,
                  line: theme.colorScheme.primary,
                  axis: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(monthLabel(months.first.year, months.first.month), style: theme.textTheme.bodySmall),
            const Spacer(),
            Text(monthLabel(months.last.year, months.last.month), style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.amounts, required this.selected, required this.line, required this.axis});

  final List<int> amounts;
  final int selected;
  final Color line;
  final Color axis;

  @override
  void paint(Canvas canvas, Size size) {
    if (amounts.isEmpty) return;
    var low = amounts.reduce((a, b) => a < b ? a : b), high = amounts.reduce((a, b) => a > b ? a : b);
    if (low > 0) low = 0;
    if (high < 0) high = 0;
    if (low == high) high = low + 1;
    const top = 8.0, bottom = 8.0;
    final height = size.height - top - bottom;
    double y(int cents) => top + height * (high - cents) / (high - low);
    double x(int index) => amounts.length == 1 ? size.width / 2 : size.width * index / (amounts.length - 1);

    // The zero line.
    canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), Paint()..color = axis);

    final path = Path()..moveTo(x(0), y(amounts.first));
    for (var i = 1; i < amounts.length; i++) {
      path.lineTo(x(i), y(amounts[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = line;
    if (amounts.length <= 36) {
      for (var i = 0; i < amounts.length; i++) {
        canvas.drawCircle(Offset(x(i), y(amounts[i])), 2.5, dot);
      }
    }
    // The month shown.
    final selectedPoint = Offset(x(selected), y(amounts[selected]));
    canvas.drawLine(
      Offset(selectedPoint.dx, top),
      Offset(selectedPoint.dx, size.height - bottom),
      Paint()..color = axis,
    );
    canvas.drawCircle(selectedPoint, 5, dot);
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.selected != selected || old.line != line || old.axis != axis || !_same(old.amounts, amounts);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
