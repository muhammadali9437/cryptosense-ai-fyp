import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/explain.dart';
import '../widgets/panel.dart';
import '../widgets/pop.dart';
import '../widgets/tappable.dart';

const _checklist = [
  'Do I understand what problem this coin solves?',
  'Is trading volume steady, or was it one big spike?',
  'Who holds most of the supply? A few wallets can sell on everyone at once.',
  'Could I lose this whole amount and still be fine?',
  'Have I picked my stop-loss before buying?',
];

/// New listings: recently listed coins with a risk rating and a pre-buy checklist.
class ListingsScreen extends StatelessWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild when the backend sends the real Binance listings
    return ListenableBuilder(listenable: context.app, builder: (context, _) => _page(context));
  }

  Widget _page(BuildContext context) {
    final app = context.app;
    return PageBody(children: [
      Panel(
        title: 'New coins move fast, both ways',
        explain: 'listings',
        trailing: AppButton(
          label: 'Before you buy',
          icon: Icons.checklist_rounded,
          kind: ButtonKind.ghost,
          compact: true,
          onTap: () => _showChecklist(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SageAvatar(size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A new listing can double in a day and halve the next. Use these cards to spot the calmer ones and '
                    'the wild ones, and never put in more than you could afford to lose completely.',
                    style: AppText.body(15, height: 1.6),
                  ),
                ),
              ],
            ),
            DemoNote(app.listingsLive
                ? 'Live from Binance: coins listed in the last 60 days, rated by volatility and volume.'
                : 'Demo listings. Start the backend to scan Binance for real new listings.'),
          ],
        ),
      ),
      TileGrid(minTileWidth: 340, children: [for (final l in app.listings) _ListingCard(item: l)]),
    ]);
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.item});
  final NewListing item;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: () => _open(context, item),
      semanticLabel: item.name,
      pressScale: 0.99,
      builder: (context, s) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 250,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: s.hover ? AppColors.panelHi : AppColors.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: s.focus ? AppColors.text : (s.hover ? AppColors.brass.fade(0.4) : AppColors.line),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CoinAvatar(item.symbol, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: AppText.body(16, w: FontWeight.w600)),
                      Text('${item.symbol}, listed ${Fmt.ago(item.listedAt)}',
                          style: AppText.body(12.5, color: AppColors.muted)),
                    ],
                  ),
                ),
                Tag(item.category, color: AppColors.calm),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _Figure(label: 'Since listing', child: ChangeText(item.changeSinceListing, size: 18))),
                Expanded(
                  child: _Figure(
                    label: '24h volume',
                    child: Text(Fmt.compact(item.volume24h), style: AppText.number(18)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Text(item.note,
                  maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.body(13.5, color: AppColors.muted)),
            ),
            RiskMeter(level: item.risk),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(12.5, color: AppColors.faint)),
          const SizedBox(height: 2),
          child,
        ],
      );
}

Widget _checklistView() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in _checklist)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_box_outline_blank_rounded, size: 18, color: AppColors.brass),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(c, style: AppText.body(14.5, height: 1.5))),
              ],
            ),
          ),
      ],
    );

Future<void> _showChecklist(BuildContext context) => showPop<void>(
      context,
      child: Builder(
        builder: (ctx) => PopCard(
          title: 'Before you buy a new coin',
          subtitle: 'Five honest questions',
          icon: Icons.checklist_rounded,
          actions: [AppButton(label: 'Got it', onTap: () => Navigator.of(ctx).pop())],
          child: _checklistView(),
        ),
      ),
    );

Future<void> _open(BuildContext context, NewListing l) => showPop<void>(
      context,
      maxWidth: 560,
      child: Builder(
        builder: (ctx) => PopCard(
          title: '${l.name} (${l.symbol})',
          subtitle: '${l.category}, listed ${Fmt.ago(l.listedAt)}',
          leading: CoinAvatar(l.symbol, size: 40),
          actions: [AppButton(label: 'Got it', onTap: () => Navigator.of(ctx).pop())],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _Figure(label: 'Since listing', child: ChangeText(l.changeSinceListing, size: 20))),
                  Expanded(
                    child: _Figure(
                      label: '24h volume',
                      child: Text(Fmt.compact(l.volume24h), style: AppText.number(20)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RiskMeter(level: l.risk),
              const SizedBox(height: 14),
              Text(l.note, style: AppText.body(15, height: 1.6)),
              const SizedBox(height: 20),
              Text('Ask yourself first', style: AppText.body(15, w: FontWeight.w600)),
              const SizedBox(height: 10),
              _checklistView(),
            ],
          ),
        ),
      ),
    );