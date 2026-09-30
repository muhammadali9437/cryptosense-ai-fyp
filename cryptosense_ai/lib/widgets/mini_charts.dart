import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Tiny price line used in the watchlist.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.width = 96, this.height = 32});
  final List<double> values;
  final double width, height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _SparkPainter(values)),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce(min), hi = values.reduce(max);
    final range = hi - lo == 0 ? 1 : hi - lo;
    final color = values.last >= values.first ? AppColors.bull : AppColors.bear;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height - (values[i] - lo) / range * (size.height - 4) - 2;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.fade(0.25), color.fade(0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values;
}

class DonutSlice {
  const DonutSlice(this.value, this.color);
  final double value;
  final Color color;
}

/// Allocation ring for the portfolio.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.size = 180, this.stroke = 18, this.center});
  final List<DonutSlice> slices;
  final double size, stroke;
  final Widget? center;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: Size.square(size), painter: _DonutPainter(slices, stroke)),
            if (center != null) center!,
          ],
        ),
      );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.stroke);
  final List<DonutSlice> slices;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.line;
    canvas.drawArc(rect, 0, 2 * pi, false, track);

    final total = slices.fold(0.0, (s, e) => s + e.value);
    if (total <= 0) return;
    final gap = slices.length > 1 ? 0.05 : 0.0;
    var start = -pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * 2 * pi;
      canvas.drawArc(
        rect,
        start + gap / 2,
        max(0.0, sweep - gap),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = s.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}

/// Half-circle gauge for the market mood score (0..100).
class MoodGauge extends StatelessWidget {
  const MoodGauge({super.key, required this.value, required this.label, this.width = 220});
  final double value;
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: Duration(milliseconds: reduceMotion ? 0 : 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: width,
        height: width * 0.64,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GaugePainter(v))),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                children: [
                  Text(v.round().toString(), style: AppText.display(38)),
                  Text(label, style: AppText.body(14, color: AppColors.muted, w: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 14;
    final center = Offset(size.width / 2, r + 14);
    final rect = Rect.fromCircle(center: center, radius: r);

    canvas.drawArc(
      rect,
      pi,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..color = AppColors.line,
    );
    canvas.drawArc(
      rect,
      pi,
      pi * value / 100,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          startAngle: pi,
          endAngle: 2 * pi,
          colors: [AppColors.bear, AppColors.warn, AppColors.brass, AppColors.bull],
        ).createShader(rect),
    );

    final a = pi + pi * value / 100;
    final knob = center + Offset(cos(a) * r, sin(a) * r);
    canvas.drawCircle(knob, 10, Paint()..color = AppColors.ink);
    canvas.drawCircle(knob, 6, Paint()..color = AppColors.text);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}
