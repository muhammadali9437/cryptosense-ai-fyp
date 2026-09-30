import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/market_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'tappable.dart';

/// Small reusable pieces: trend badge, % change, coin avatar, tags, notes.

Color trendColor(Trend t) => switch (t) {
      Trend.bullish => AppColors.bull,
      Trend.bearish => AppColors.bear,
      Trend.neutral => AppColors.calm,
    };

IconData trendIcon(Trend t) => switch (t) {
      Trend.bullish => Icons.north_east_rounded,
      Trend.bearish => Icons.south_east_rounded,
      Trend.neutral => Icons.east_rounded,
    };

class TrendBadge extends StatelessWidget {
  const TrendBadge({super.key, required this.trend});
  final Trend trend;

  @override
  Widget build(BuildContext context) {
    final c = trendColor(trend);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.fade(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.fade(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon(trend), size: 14, color: c),
          const SizedBox(width: 5),
          Text(trend.label, style: AppText.body(12.5, color: c, w: FontWeight.w600)),
        ],
      ),
    );
  }
}

class ChangeText extends StatelessWidget {
  const ChangeText(this.pct, {super.key, this.size = 13});
  final double pct;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
        Fmt.pct(pct),
        style: AppText.number(size, color: pct >= 0 ? AppColors.bull : AppColors.bear),
      );
}

class CoinAvatar extends StatelessWidget {
  const CoinAvatar(this.base, {super.key, this.size = 36});
  final String base;
  final double size;

  static const _colors = {
    'BTC': Color(0xFFF2A33A),
    'ETH': Color(0xFF9A9CF5),
    'BNB': Color(0xFFE9C44A),
    'SOL': Color(0xFFB07CFF),
    'XRP': Color(0xFF8FB3D9),
    'ADA': Color(0xFF5E8BF2),
    'USDT': Color(0xFF4FBF9A),
  };

  static Color colorFor(String base) =>
      _colors[base] ??
      HSLColor.fromAHSL(1, (base.hashCode.abs() % 360).toDouble(), 0.55, 0.65).toColor();

  @override
  Widget build(BuildContext context) {
    final c = colorFor(base);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.fade(0.16),
        border: Border.all(color: c.fade(0.5)),
      ),
      child: Text(
        base.length > 3 ? base.substring(0, 3) : base,
        style: AppText.body(size * 0.3, color: c, w: FontWeight.w700),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = AppColors.muted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.fade(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: AppText.body(12, color: color, w: FontWeight.w600)),
      );
}

/// Three bars: lower / medium / high risk.
class RiskMeter extends StatelessWidget {
  const RiskMeter({super.key, required this.level});
  final int level; // 0..2

  static String label(int level) => const ['Lower risk', 'Medium risk', 'High risk'][level];
  static Color color(int level) => const [AppColors.bull, AppColors.warn, AppColors.bear][level];

  @override
  Widget build(BuildContext context) {
    final c = color(level);
    return Tooltip(
      message: label(level),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 6,
              height: 10.0 + i * 5,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: i <= level ? c : AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(width: 8),
          Text(label(level), style: AppText.body(12.5, color: c, w: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Quiet note that tells the examiner/user which data is still simulated.
class DemoNote extends StatelessWidget {
  const DemoNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.faint),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: AppText.body(12.5, color: AppColors.faint))),
          ],
        ),
      );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 16),
        child: Text(text, style: AppText.body(13.5, color: AppColors.muted, w: FontWeight.w600)),
      );
}

/// Pick one of the tracked coins. Optionally shows each coin's 24h change.
class CoinChoice extends StatelessWidget {
  const CoinChoice({super.key, required this.selected, required this.onChanged, this.tickers});
  final String selected;
  final ValueChanged<String> onChanged;
  final Map<String, Ticker>? tickers;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in MarketService.symbols)
          Tappable(
            onTap: () => onChanged(s),
            semanticLabel: s,
            builder: (context, st) {
              final on = s == selected;
              final base = s.replaceAll('USDT', '');
              final t = tickers?[s];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
                decoration: BoxDecoration(
                  color: on ? AppColors.brass.fade(0.14) : (st.hover ? AppColors.panelHi : AppColors.ink),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: on ? AppColors.brass : (st.focus ? AppColors.text : AppColors.line),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CoinAvatar(base, size: 26),
                    const SizedBox(width: 8),
                    Text(base,
                        style: AppText.body(13.5,
                            color: on ? AppColors.text : AppColors.muted, w: FontWeight.w600)),
                    if (t != null) ...[
                      const SizedBox(width: 8),
                      ChangeText(t.changePct, size: 12.5),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
