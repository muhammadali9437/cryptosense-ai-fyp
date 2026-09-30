import 'dart:math';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_scope.dart';
import '../services/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/explain.dart';
import '../widgets/panel.dart';
import '../widgets/pop.dart';

/// Profit & loss limits: a stop-loss and take-profit for every holding,
/// with a live bar showing where the position sits between the two.
class LimitsScreen extends StatelessWidget {
  const LimitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => PageBody(maxWidth: 980, children: [
        Panel(
          explain: 'limits',
          title: 'Plan your exits before you need them',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SageAvatar(size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "A stop-loss is where you say \"I was wrong, I'll get out.\" A take-profit is where you say "
                  '"this is good enough." Setting both while you are calm is one of the best habits a new investor '
                  'can build. CryptoSense will alert you the moment either one is reached.',
                  style: AppText.body(15, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        if (app.holdings.isEmpty)
          Panel(
            child: Column(
              children: [
                Text('Add a coin to your portfolio first, then set its limits here.',
                    style: AppText.body(15, color: AppColors.muted)),
                const SizedBox(height: 14),
                AppButton(label: 'Go to Portfolio', onTap: () => app.go(1)),
              ],
            ),
          ),
        for (final h in app.holdings) _LimitCard(key: ValueKey(h.symbol), holding: h),
      ]),
    );
  }
}

class _LimitCard extends StatefulWidget {
  const _LimitCard({super.key, required this.holding});
  final Holding holding;

  @override
  State<_LimitCard> createState() => _LimitCardState();
}

class _LimitCardState extends State<_LimitCard> {
  late bool _stopOn = widget.holding.stopLossPct != null;
  late bool _takeOn = widget.holding.takeProfitPct != null;
  late double _stop = widget.holding.stopLossPct ?? 10;
  late double _take = widget.holding.takeProfitPct ?? 25;

  bool get _dirty =>
      (_stopOn ? _stop : null) != widget.holding.stopLossPct ||
      (_takeOn ? _take : null) != widget.holding.takeProfitPct;

  void _save() {
    context.app.setLimits(widget.holding.symbol, _stopOn ? _stop : null, _takeOn ? _take : null);
    toast(context, 'Limits saved for ${widget.holding.base}');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.holding;
    final market = context.market;
    final name = MockData.names[h.symbol] ?? h.base;

    return ListenableBuilder(
      listenable: market,
      builder: (context, _) {
        final price = market.tickers[h.symbol]?.price ?? h.avgBuy;
        final pnlPct = (price - h.avgBuy) / h.avgBuy * 100;
        final invested = h.amount * h.avgBuy;
        final stopPrice = h.avgBuy * (1 - _stop / 100);
        final takePrice = h.avgBuy * (1 + _take / 100);

        return Panel(
          title: name,
          subtitle:
              '${Fmt.coin(h.amount)} ${h.base} bought at ${Fmt.usd(h.avgBuy)}. Now ${Fmt.usd(price)} (${Fmt.pct(pnlPct)}).',
          trailing: CoinAvatar(h.base, size: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RiskBar(pnl: pnlPct, stop: _stopOn ? _stop : null, target: _takeOn ? _take : null),
              const SizedBox(height: 22),
              _LimitSlider(
                title: 'Stop-loss',
                color: AppColors.bear,
                enabled: _stopOn,
                onToggle: (v) => setState(() => _stopOn = v),
                value: _stop,
                min: 1,
                max: 50,
                divisions: 49,
                valueText: '-${_stop.round()}%',
                caption: _stopOn
                    ? 'Alert me if ${h.base} falls to ${Fmt.usd(stopPrice)}. At that point you would be down about ${Fmt.usd(invested * _stop / 100)}.'
                    : 'Off. Without a stop-loss, a falling coin has no exit plan.',
                onChanged: (v) => setState(() => _stop = v),
              ),
              const SizedBox(height: 12),
              _LimitSlider(
                title: 'Take-profit',
                color: AppColors.bull,
                enabled: _takeOn,
                onToggle: (v) => setState(() => _takeOn = v),
                value: _take,
                min: 5,
                max: 200,
                divisions: 39,
                valueText: '+${_take.round()}%',
                caption: _takeOn
                    ? 'Alert me if ${h.base} rises to ${Fmt.usd(takePrice)}. That would be a gain of about ${Fmt.usd(invested * _take / 100)}.'
                    : 'Off. A target helps you lock in gains instead of hoping for more.',
                onChanged: (v) => setState(() => _take = v),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: _dirty ? 'Save limits' : 'Saved',
                  icon: _dirty ? Icons.save_outlined : Icons.check_rounded,
                  kind: _dirty ? ButtonKind.primary : ButtonKind.ghost,
                  onTap: _dirty ? _save : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LimitSlider extends StatelessWidget {
  const _LimitSlider({
    required this.title,
    required this.color,
    required this.enabled,
    required this.onToggle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueText,
    required this.caption,
    required this.onChanged,
  });

  final String title;
  final Color color;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final double value, min, max;
  final int divisions;
  final String valueText;
  final String caption;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: enabled ? color.fade(0.35) : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: AppText.body(15, w: FontWeight.w600)),
              const SizedBox(width: 10),
              if (enabled) Text(valueText, style: AppText.number(15, color: color)),
              const Spacer(),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeTrackColor: color,
                inactiveTrackColor: AppColors.line,
                thumbColor: const WidgetStatePropertyAll(AppColors.text),
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.fade(0.15),
            ),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              label: valueText,
              onChanged: enabled ? onChanged : null,
            ),
          ),
          Text(caption, style: AppText.body(13.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Horizontal bar from the stop-loss (left) to the target (right),
/// with a dot showing the position's current profit or loss.
class _RiskBar extends StatelessWidget {
  const _RiskBar({required this.pnl, this.stop, this.target});
  final double pnl;
  final double? stop;
  final double? target;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      var lo = -(stop ?? 30.0);
      var hi = target ?? 60.0;
      lo = min(lo, pnl - 5);
      hi = max(hi, pnl + 5);
      double x(double v) => (v - lo) / (hi - lo) * w;
      final zero = x(0);
      final px = x(pnl).clamp(8.0, max(8.0, w - 8)).toDouble();
      final up = pnl >= 0;

      return SizedBox(
        height: 70,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: (px - 50).clamp(0.0, max(0.0, w - 100)).toDouble(),
              width: 100,
              top: 0,
              child: Text('You ${Fmt.pct(pnl)}',
                  textAlign: TextAlign.center,
                  style: AppText.number(12.5, color: up ? AppColors.bull : AppColors.bear)),
            ),
            Positioned(
              left: 0,
              width: zero,
              top: 28,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.bear.fade(0.35),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                ),
              ),
            ),
            Positioned(
              left: zero,
              right: 0,
              top: 28,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.bull.fade(0.35),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ),
            ),
            Positioned(left: zero - 1, top: 22, width: 2, height: 20, child: const ColoredBox(color: AppColors.muted)),
            if (stop != null)
              Positioned(left: x(-stop!) - 1, top: 22, width: 2, height: 20, child: const ColoredBox(color: AppColors.bear)),
            if (target != null)
              Positioned(left: x(target!) - 1, top: 22, width: 2, height: 20, child: const ColoredBox(color: AppColors.bull)),
            Positioned(
              left: px - 9,
              top: 23,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.text,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 3),
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: Text(stop != null ? 'Stop -${stop!.round()}%' : 'No stop set',
                  style: AppText.body(12.5, color: AppColors.muted)),
            ),
            Positioned(
              left: (zero - 40).clamp(0.0, max(0.0, w - 80)).toDouble(),
              width: 80,
              bottom: 0,
              child: Text('Break-even',
                  textAlign: TextAlign.center, style: AppText.body(12.5, color: AppColors.faint)),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Text(target != null ? 'Target +${target!.round()}%' : 'No target set',
                  style: AppText.body(12.5, color: AppColors.muted)),
            ),
          ],
        ),
      );
    });
  }
}