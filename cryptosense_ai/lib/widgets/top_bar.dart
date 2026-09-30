import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'account.dart';
import 'bits.dart';
import 'sidebar.dart';

/// Page title, BTC/ETH price chips, live/demo status, clock, account and tour button.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.showMenu, required this.onMenu, required this.onHelp});
  final bool showMenu;
  final VoidCallback onMenu;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final market = context.market;
    final app = context.app;
    return ListenableBuilder(
      listenable: Listenable.merge([market, app]),
      builder: (context, _) {
        final e = navEntries[app.page];
        final width = MediaQuery.sizeOf(context).width;
        final showChips = width >= 1180;
        final showSub = width >= 700;

        return Container(
          padding: EdgeInsets.fromLTRB(showMenu ? 8 : 28, 14, 16, 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
          child: Row(
            children: [
              if (showMenu)
                IconButton(
                  tooltip: 'Menu',
                  onPressed: onMenu,
                  icon: const Icon(Icons.menu_rounded, color: AppColors.text),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.title, style: AppText.display(showSub ? 22 : 19), overflow: TextOverflow.ellipsis),
                    if (showSub)
                      Text(e.subtitle,
                          style: AppText.body(13.5, color: AppColors.muted), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (showChips) ...[
                _TickerChip(market.ticker('BTCUSDT')),
                const SizedBox(width: 8),
                _TickerChip(market.ticker('ETHUSDT')),
                const SizedBox(width: 12),
              ],
              _LiveBadge(live: market.isLive),
              if (showSub) ...[const SizedBox(width: 12), const _Clock()],
              const SizedBox(width: 12),
              const AccountButton(),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Take the tour again',
                onPressed: onHelp,
                icon: const Icon(Icons.help_outline_rounded, color: AppColors.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TickerChip extends StatelessWidget {
  const _TickerChip(this.t);
  final Ticker t;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.base, style: AppText.body(12.5, color: AppColors.muted, w: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(Fmt.usd(t.price), style: AppText.number(13.5)),
            const SizedBox(width: 8),
            ChangeText(t.changePct, size: 12.5),
          ],
        ),
      );
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge({required this.live});
  final bool live;

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.live ? AppColors.bull : AppColors.warn;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Tooltip(
      message: widget.live
          ? 'Prices are streaming live from Binance.'
          : "Couldn't reach Binance, so prices are simulated. Check your connection.",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.fade(0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.fade(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: reduceMotion
                  ? const AlwaysStoppedAnimation(1.0)
                  : Tween(begin: 0.35, end: 1.0).animate(_pulse),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.live ? 'Live' : 'Demo data',
                style: AppText.body(12.5, color: color, w: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(Fmt.clock(_now), style: AppText.number(13.5, color: AppColors.muted, w: FontWeight.w500));
}