import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/explain.dart';
import '../widgets/panel.dart';
import '../widgets/pop.dart';
import '../widgets/tappable.dart';
import 'dashboard_screen.dart' show whaleColor, whaleIcon;

/// Whale watch: large transfers, exchange inflow vs outflow, and what they mean.
class WhaleScreen extends StatefulWidget {
  const WhaleScreen({super.key});

  @override
  State<WhaleScreen> createState() => _WhaleScreenState();
}

class _WhaleScreenState extends State<WhaleScreen> {
  final List<WhaleTx> _feed = [...MockData.whaleSeed];
  final Set<String> _fresh = {};
  String _filter = 'all';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Simulated live feed: a new whale move every ~7 seconds.
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      final tx = MockData.randomWhale();
      setState(() {
        _feed.insert(0, tx);
        if (_feed.length > 40) _feed.removeLast();
        _fresh.add(tx.id);
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _fresh.remove(tx.id));
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hourAgo = DateTime.now().subtract(const Duration(hours: 1));
    double sum(WhaleFlow f) => _feed
        .where((t) => t.flow == f && t.time.isAfter(hourAgo))
        .fold(0.0, (s, t) => s + t.usd);
    final inflow = sum(WhaleFlow.toExchange);
    final outflow = sum(WhaleFlow.fromExchange);
    final total = inflow + outflow;

    final read = total == 0
        ? 'No large exchange flows in the last hour. Quiet whales usually mean no big pressure either way.'
        : inflow > outflow * 1.2
            ? 'More money is moving onto exchanges than off them. Some big holders may be getting ready to sell, so watch for selling pressure.'
            : outflow > inflow * 1.2
                ? 'More money is leaving exchanges than arriving. Big holders seem to be moving coins into storage, which usually means they plan to hold.'
                : 'Money is flowing in and out of exchanges in roughly equal amounts. Whales are not leaning strongly in either direction.';

    final shown = _feed.where((t) => _filter == 'all' || t.flow.name == _filter).toList();

    return PageBody(maxWidth: 1100, children: [
      Panel(
        title: 'Exchange flows in the last hour',
        subtitle: 'Where the biggest wallets are sending their coins',
        explain: 'whales',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 32,
              runSpacing: 16,
              children: [
                _FlowFigure(label: 'Onto exchanges', value: inflow, color: AppColors.warn, note: 'possible selling'),
                _FlowFigure(label: 'Off exchanges', value: outflow, color: AppColors.bull, note: 'likely holding'),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: total == 0 ? 1 : (inflow / total * 1000).round().clamp(1, 1000),
                      child: Container(color: AppColors.warn),
                    ),
                    Expanded(
                      flex: total == 0 ? 1 : (outflow / total * 1000).round().clamp(1, 1000),
                      child: Container(color: AppColors.bull),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SageAvatar(size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text(read, style: AppText.body(15, height: 1.55))),
              ],
            ),
          ],
        ),
      ),
      Panel(
        title: 'Live whale feed',
        subtitle: 'Transfers worth millions. Tap one to see what it could mean.',
        trailing: SegmentPills(
          options: const ['all', 'toExchange', 'fromExchange', 'walletToWallet'],
          labels: const {
            'all': 'All',
            'toExchange': 'Onto exchanges',
            'fromExchange': 'Off exchanges',
            'walletToWallet': 'Between wallets',
          },
          selected: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        child: Column(
          children: [
            for (final t in shown) _WhaleRow(tx: t, fresh: _fresh.contains(t.id)),
            const DemoNote(
                'Simulated feed. Real transfers (Whale Alert API / Etherscan) are connected in the backend step.'),
          ],
        ),
      ),
    ]);
  }
}

class _FlowFigure extends StatelessWidget {
  const _FlowFigure({required this.label, required this.value, required this.color, required this.note});
  final String label;
  final double value;
  final Color color;
  final String note;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: AppText.body(14, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(Fmt.compact(value), style: AppText.display(30)),
          Text(note, style: AppText.body(13, color: color)),
        ],
      );
}

class _WhaleRow extends StatelessWidget {
  const _WhaleRow({required this.tx, required this.fresh});
  final WhaleTx tx;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final c = whaleColor(tx.flow);
    return Tappable(
      onTap: () => _open(context),
      semanticLabel: '${tx.coin} whale transfer',
      pressScale: 0.99,
      builder: (context, s) => AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fresh ? AppColors.brass.fade(0.1) : (s.hover ? AppColors.panelHi : AppColors.ink),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: s.focus ? AppColors.text : (fresh ? AppColors.brass.fade(0.5) : AppColors.line),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: c.fade(0.14), shape: BoxShape.circle),
              child: Icon(whaleIcon(tx.flow), size: 19, color: c),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${Fmt.coin(tx.amount)} ${tx.coin}', style: AppText.number(15)),
                  Text('${tx.from} to ${tx.to}',
                      overflow: TextOverflow.ellipsis, style: AppText.body(13, color: AppColors.muted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.compact(tx.usd), style: AppText.number(15)),
                Text(Fmt.ago(tx.time), style: AppText.body(12.5, color: AppColors.faint)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) => showPop<void>(
        context,
        child: Builder(
          builder: (ctx) => PopCard(
            title: '${Fmt.coin(tx.amount)} ${tx.coin} (${Fmt.compact(tx.usd)})',
            subtitle: '${tx.flow.label}, ${Fmt.ago(tx.time)}',
            icon: whaleIcon(tx.flow),
            accent: whaleColor(tx.flow),
            actions: [AppButton(label: 'Got it', onTap: () => Navigator.of(ctx).pop())],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _End(label: 'From', value: tx.from)),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward_rounded, color: AppColors.faint),
                    const SizedBox(width: 12),
                    Expanded(child: _End(label: 'To', value: tx.to)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SageAvatar(size: 28),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tx.flow.meaning, style: AppText.body(15, height: 1.6))),
                  ],
                ),
                const SizedBox(height: 16),
                const TipBox('One transfer on its own means little. Look for several big moves in the same direction.'),
              ],
            ),
          ),
        ),
      );
}

class _End extends StatelessWidget {
  const _End({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.body(12.5, color: AppColors.faint)),
            Text(value, style: AppText.body(14.5, w: FontWeight.w600)),
          ],
        ),
      );
}
