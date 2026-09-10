import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../main.dart';
import '../../features/dashboard/models/dashboard_models.dart';

/// Charts drawn with CustomPainter.
///
/// ponytail: no charting package — three shapes at this fidelity are less code
/// than wiring one up, and nothing here needs zoom, brushing or live streaming.
/// Reach for a library if those become requirements.

/// Shared axis/label styling so all three charts read as one system.
const _gridColor = Color(0xFFEDEDF5);
const _labelStyle = TextStyle(fontSize: 11, color: kMuted);

TextPainter _label(String text, {TextStyle style = _labelStyle}) =>
    TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

/// Filled line chart for business performance over time.
class AreaChart extends StatelessWidget {
  const AreaChart({super.key, required this.series, this.height = 220});

  final PerformanceSeries series;
  final double height;

  @override
  Widget build(BuildContext context) {
    final values = series.values;
    return Semantics(
      label: values.isEmpty
          ? 'Business performance chart, no data'
          : 'Business performance chart, ${values.length} points, '
              'ranging ${values.reduce(math.min).round()} to '
              '${values.reduce(math.max).round()}',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _AreaPainter(series)),
      ),
    );
  }
}

class _AreaPainter extends CustomPainter {
  _AreaPainter(this.series);

  final PerformanceSeries series;

  @override
  void paint(Canvas canvas, Size size) {
    final values = series.values;
    if (values.isEmpty) return;

    const leftPad = 34.0;
    const bottomPad = 22.0;
    final plot = Rect.fromLTRB(leftPad, 6, size.width, size.height - bottomPad);
    if (plot.width <= 0 || plot.height <= 0) return;

    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    // Pad the range so the line never sits flat on an edge.
    final top = (maxV + (maxV - minV) * .15).ceilToDouble();
    final bottom = math.max(0, minV - (maxV - minV) * .15).floorToDouble();
    final span = math.max(top - bottom, 1);

    double y(double v) => plot.bottom - (v - bottom) / span * plot.height;
    double x(int i) => values.length == 1
        ? plot.center.dx
        : plot.left + i / (values.length - 1) * plot.width;

    // Horizontal gridlines + y labels.
    final grid = Paint()
      ..color = _gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final v = bottom + span * i / 4;
      final gy = y(v);
      canvas.drawLine(Offset(plot.left, gy), Offset(plot.right, gy), grid);
      final tp = _label(v.round().toString());
      tp.paint(canvas, Offset(plot.left - tp.width - 8, gy - tp.height / 2));
    }

    final path = Path()..moveTo(x(0), y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }

    // Fill under the line, then the line itself on top.
    final fill = Path.from(path)
      ..lineTo(x(values.length - 1), plot.bottom)
      ..lineTo(x(0), plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kIndigo.withValues(alpha: .22),
            kIndigo.withValues(alpha: .02),
          ],
        ).createShader(plot),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = kIndigo
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // X labels: thin them out so they never collide on a narrow chart.
    final maxLabels = math.max(2, (plot.width / 46).floor());
    final step = (values.length / maxLabels).ceil();
    for (var i = 0; i < values.length; i += step) {
      final tp = _label(series.labels[i]);
      tp.paint(
        canvas,
        Offset(
          (x(i) - tp.width / 2).clamp(0, size.width - tp.width),
          size.height - tp.height - 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_AreaPainter old) => old.series != series;
}

/// Grouped bars: active vs inactive users per bucket.
class UserActivityChart extends StatelessWidget {
  const UserActivityChart({
    super.key,
    required this.buckets,
    this.height = 200,
  });

  final List<({String label, int active, int inactive})> buckets;
  final double height;

  static const activeColor = kIndigo;
  static const inactiveColor = Color(0xFFC7C4E8);

  @override
  Widget build(BuildContext context) {
    final total = buckets.fold(0, (s, b) => s + b.active + b.inactive);
    return Semantics(
      label: 'Active versus inactive users across ${buckets.length} periods, '
          '$total users total',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _BarPainter(buckets)),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.buckets);

  final List<({String label, int active, int inactive})> buckets;

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    const bottomPad = 20.0;
    final plot = Rect.fromLTRB(0, 6, size.width, size.height - bottomPad);
    if (plot.width <= 0 || plot.height <= 0) return;

    final maxV = buckets
        .map((b) => math.max(b.active, b.inactive))
        .reduce(math.max)
        .toDouble();
    if (maxV <= 0) return;

    final grid = Paint()
      ..color = _gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final gy = plot.bottom - plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, gy), Offset(plot.right, gy), grid);
    }

    final slot = plot.width / buckets.length;
    // Two bars plus a hairline gap, inside a slot that keeps its own margins.
    final barW = math.max(3.0, math.min(14.0, slot * .28));
    for (final (i, b) in buckets.indexed) {
      final centre = plot.left + slot * (i + .5);
      for (final (j, pair) in [
        (UserActivityChart.activeColor, b.active),
        (UserActivityChart.inactiveColor, b.inactive),
      ].indexed) {
        final h = plot.height * (pair.$2 / maxV);
        final left = centre - barW - 1 + j * (barW + 2);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left, plot.bottom - h, barW, h),
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          Paint()..color = pair.$1,
        );
      }
      final tp = _label(b.label);
      tp.paint(
        canvas,
        Offset(
          (centre - tp.width / 2).clamp(0, size.width - tp.width),
          size.height - tp.height - 3,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.buckets != buckets;
}

/// Donut for the project status breakdown, with the total in the middle.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.size = 160});

  final List<({ProjectStatus status, int count})> slices;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold(0, (s, e) => s + e.count);
    return Semantics(
      label: 'Project status breakdown: '
          '${slices.map((s) => '${s.count} ${s.status.label}').join(', ')}',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DonutPainter(slices, total),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
                const Text('Projects', style: _labelStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.total);

  final List<({ProjectStatus status, int count})> slices;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final stroke = size.shortestSide * .16;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - stroke) / 2,
    );
    var start = -math.pi / 2;
    for (final s in slices) {
      if (s.count <= 0) continue;
      final sweep = s.count / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        // Hairline gap between slices, but never wider than the slice itself.
        math.max(sweep - .02, sweep * .5),
        false,
        Paint()
          ..color = s.status.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.total != total;
}

/// Legend row shared by the bar and donut charts.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.entries});

  final List<({String label, Color color, String? value})> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final e in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: e.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(e.label, style: const TextStyle(fontSize: 12, color: kMuted)),
              if (e.value != null) ...[
                const SizedBox(width: 6),
                Text(
                  e.value!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
