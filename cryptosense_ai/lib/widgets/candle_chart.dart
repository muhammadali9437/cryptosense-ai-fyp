import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

String chartPrice(double p) => p >= 1000
    ? NumberFormat('#,##0').format(p)
    : p >= 1
        ? p.toStringAsFixed(2)
        : p.toStringAsFixed(4);

/// Interactive candlestick chart with volume bars and a live-price line.
/// Hover (desktop) or drag (touch) to read any candle.
class CandleChart extends StatefulWidget {
  const CandleChart({super.key, required this.candles, this.height = 320});
  final List<Candle> candles;
  final double height;

  @override
  State<CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends State<CandleChart> {
  int? _hover;

  void _track(Offset pos, double width) {
    final n = widget.candles.length;
    if (n == 0) return;
    final chartW = width - CandlePainter.axisWidth;
    final i = (pos.dx / chartW * n).floor().clamp(0, n - 1);
    if (i != _hover) setState(() => _hover = i);
  }

  void _clear() {
    if (_hover != null) setState(() => _hover = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.candles;
    if (c.isEmpty) return SizedBox(height: widget.height + 32);
    final shown = c[(_hover ?? c.length - 1).clamp(0, c.length - 1)];
    final change = (shown.close - shown.open) / shown.open * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(DateFormat('EEE d MMM, HH:mm').format(shown.time),
                style: AppText.body(12.5, color: AppColors.muted)),
            _ohlc('Open', shown.open),
            _ohlc('High', shown.high),
            _ohlc('Low', shown.low),
            _ohlc('Close', shown.close),
            Text(
              '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
              style: AppText.number(12.5, color: change >= 0 ? AppColors.bull : AppColors.bear),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) => MouseRegion(
            onHover: (e) => _track(e.localPosition, box.maxWidth),
            onExit: (_) => _clear(),
            child: GestureDetector(
              onTapDown: (d) => _track(d.localPosition, box.maxWidth),
              onHorizontalDragUpdate: (d) => _track(d.localPosition, box.maxWidth),
              onHorizontalDragEnd: (_) => _clear(),
              child: SizedBox(
                height: widget.height,
                width: box.maxWidth,
                child: CustomPaint(painter: CandlePainter(c, _hover)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ohlc(String label, double v) => Text.rich(TextSpan(children: [
        TextSpan(text: '$label ', style: AppText.body(12.5, color: AppColors.faint)),
        TextSpan(text: chartPrice(v), style: AppText.number(12.5)),
      ]));
}

class CandlePainter extends CustomPainter {
  CandlePainter(this.candles, this.hover);
  final List<Candle> candles;
  final int? hover;

  static const axisWidth = 66.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    final chartW = size.width - axisWidth;
    final priceH = size.height * 0.78;
    final volTop = size.height * 0.84;
    final volH = size.height - volTop;

    var hi = candles.map((c) => c.high).reduce(max);
    var lo = candles.map((c) => c.low).reduce(min);
    final pad = (hi - lo) * 0.08;
    hi += pad;
    lo -= pad;
    if (hi == lo) {
      hi += 1;
      lo -= 1;
    }
    double y(double p) => (hi - p) / (hi - lo) * priceH;

    // Grid + price axis
    final grid = Paint()
      ..color = AppColors.line.fade(0.7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final gy = priceH * i / 4;
      canvas.drawLine(Offset(0, gy), Offset(chartW, gy), grid);
      _label(canvas, chartPrice(hi - (hi - lo) * i / 4),
          Offset(chartW + 8, (gy - 7).clamp(0.0, priceH - 14).toDouble()), AppColors.faint);
    }

    // Candles + volume
    final step = chartW / candles.length;
    final bodyW = max(1.5, step * 0.62);
    final maxVol = candles.map((c) => c.volume).reduce(max);
    final wick = Paint()..strokeWidth = 1;
    final fill = Paint();

    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final x = i * step + step / 2;
      final base = c.isUp ? AppColors.bull : AppColors.bear;
      final dim = hover != null && hover != i;
      final col = dim ? base.fade(0.5) : base;

      wick.color = col;
      canvas.drawLine(Offset(x, y(c.high)), Offset(x, y(c.low)), wick);

      final top = y(max(c.open, c.close));
      final bottom = max(y(min(c.open, c.close)), top + 1.2);
      fill.color = col;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(x - bodyW / 2, top, x + bodyW / 2, bottom), const Radius.circular(1.5)),
        fill,
      );

      final vh = maxVol == 0 ? 0.0 : c.volume / maxVol * volH;
      fill.color = base.fade(dim ? 0.16 : 0.32);
      canvas.drawRect(Rect.fromLTWH(x - bodyW / 2, size.height - vh, bodyW, vh), fill);
    }

    // Dashed live-price line with a brass tag on the axis
    final last = candles.last.close;
    final ly = y(last);
    final dash = Paint()
      ..color = AppColors.brass.fade(0.7)
      ..strokeWidth = 1;
    for (double dx = 0; dx < chartW; dx += 7) {
      canvas.drawLine(Offset(dx, ly), Offset(min(dx + 3.5, chartW), ly), dash);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(chartW + 2, ly - 10, axisWidth - 4, 20), const Radius.circular(6)),
      Paint()..color = AppColors.brass,
    );
    _label(canvas, chartPrice(last), Offset(chartW + 8, ly - 7), AppColors.ink, bold: true);

    // Crosshair
    if (hover != null) {
      final hx = hover! * step + step / 2;
      canvas.drawLine(
        Offset(hx, 0),
        Offset(hx, size.height),
        Paint()
          ..color = AppColors.text.fade(0.25)
          ..strokeWidth = 1,
      );
    }
  }

  void _label(Canvas canvas, String text, Offset at, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppText.number(10.5, color: color, w: bold ? FontWeight.w700 : FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: axisWidth - 10);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(CandlePainter old) => old.candles != candles || old.hover != hover;
}