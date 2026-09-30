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

/// News feed with sentiment tags. Tap a story for Sage's take.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final items = MockData.news.where((n) => _filter == 'all' || n.sentiment.name == _filter).toList();

    return PageBody(children: [
      Panel(
        title: 'Market news',
        subtitle: 'Each story is tagged by how it could move prices',
        explain: 'news',
        trailing: SegmentPills(
          options: const ['all', 'bullish', 'bearish', 'neutral'],
          labels: const {'all': 'All', 'bullish': 'Bullish', 'bearish': 'Bearish', 'neutral': 'Neutral'},
          selected: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ),
        child: const DemoNote('Demo headlines. Live news (NewsAPI / CryptoPanic) is connected in the backend step.'),
      ),
      if (items.isEmpty)
        Text('No stories match this filter right now.', style: AppText.body(15, color: AppColors.muted))
      else
        TileGrid(minTileWidth: 380, children: [for (final n in items) _NewsCard(item: n)]),
    ]);
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: () => _open(context, item),
      semanticLabel: item.title,
      pressScale: 0.99,
      builder: (context, s) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 220,
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
                TrendBadge(trend: item.sentiment),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${item.source}, ${Fmt.ago(item.time)}',
                      overflow: TextOverflow.ellipsis, style: AppText.body(12.5, color: AppColors.muted)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.display(17)),
            const SizedBox(height: 8),
            Expanded(
              child: Text(item.summary,
                  maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.body(14, color: AppColors.muted)),
            ),
            Wrap(spacing: 6, children: [for (final c in item.coins) Tag(c)]),
          ],
        ),
      ),
    );
  }

  static Future<void> _open(BuildContext context, NewsItem n) => showPop<void>(
        context,
        maxWidth: 600,
        child: Builder(
          builder: (ctx) => PopCard(
            title: n.title,
            subtitle: '${n.source}, ${Fmt.ago(n.time)}',
            icon: trendIcon(n.sentiment),
            accent: trendColor(n.sentiment),
            actions: [AppButton(label: 'Got it', onTap: () => Navigator.of(ctx).pop())],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  TrendBadge(trend: n.sentiment),
                  const SizedBox(width: 8),
                  for (final c in n.coins) Padding(padding: const EdgeInsets.only(right: 6), child: Tag(c)),
                ]),
                const SizedBox(height: 14),
                Text(n.summary, style: AppText.body(15.5, height: 1.6)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const SageAvatar(size: 28),
                    const SizedBox(width: 10),
                    Text("Sage's take", style: AppText.body(15, w: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(n.sageTake, style: AppText.body(15, height: 1.6)),
                const SizedBox(height: 16),
                const TipBox(
                    'Headlines move prices fast, and the first reaction is often too big. Wait for the chart to confirm before you act.'),
              ],
            ),
          ),
        ),
      );
}
