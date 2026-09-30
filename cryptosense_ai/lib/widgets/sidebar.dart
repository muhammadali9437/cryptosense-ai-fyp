import 'package:flutter/material.dart';

import '../services/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'buttons.dart';
import 'explain.dart';
import 'tappable.dart';

/// One page in the app. The index in [navEntries] is the page number.
class NavEntry {
  const NavEntry(this.label, this.icon, this.group, this.title, this.subtitle);
  final String label;
  final IconData icon;
  final String group;
  final String title;
  final String subtitle;
}

const navEntries = [
  NavEntry('Overview', Icons.space_dashboard_rounded, 'Markets', 'Overview',
      'What the market is doing right now'),
  NavEntry('Portfolio', Icons.account_balance_wallet_rounded, 'Your money', 'Portfolio',
      'Your coins, their value and your profit or loss'),
  NavEntry('Alerts', Icons.notifications_active_rounded, 'Your money', 'Alerts',
      "Get told when prices move, so you don't have to watch"),
  NavEntry('Profit & loss limits', Icons.shield_outlined, 'Your money', 'Profit & loss limits',
      'Decide your exit points before emotions do'),
  NavEntry('News', Icons.newspaper_rounded, 'Discover', 'News',
      "Headlines that can move prices, with Sage's take"),
  NavEntry('Whale watch', Icons.waves_rounded, 'Discover', 'Whale watch',
      'Big wallets moving big money'),
  NavEntry('New listings', Icons.rocket_launch_rounded, 'Discover', 'New listings',
      'Recently listed coins and how risky they are'),
  NavEntry('Academy', Icons.school_rounded, 'Learn', 'Academy',
      'Learn how the market moves, step by step'),
  NavEntry('Ask Sage', Icons.forum_rounded, 'Learn', 'Ask Sage',
      'Your market guide, in plain words'),
];

/// Left navigation. On phones it lives inside the Drawer.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.onSelect});
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final items = <Widget>[];
        String? group;
        for (var i = 0; i < navEntries.length; i++) {
          final e = navEntries[i];
          if (e.group != group) {
            group = e.group;
            items.add(Padding(
              padding: EdgeInsets.fromLTRB(14, items.isEmpty ? 4 : 22, 14, 8),
              child: Text(e.group,
                  style: AppText.body(12.5, color: AppColors.faint, w: FontWeight.w600)),
            ));
          }
          items.add(_NavItem(
            entry: e,
            selected: app.page == i,
            badge: i == 2 ? app.unseenTriggers : 0,
            onTap: () => onSelect(i),
          ));
        }

        return Container(
          width: 256,
          decoration: const BoxDecoration(
            color: AppColors.sidebar,
            border: Border(right: BorderSide(color: AppColors.line)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 22), child: _Logo()),
                Expanded(
                  child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: items),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _SageCard(onTap: () => onSelect(8)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brass, Color(0xFFB9853A)],
              ),
            ),
            child: const Icon(Icons.insights_rounded, color: AppColors.ink, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CryptoSense AI', style: AppText.display(16.5)),
                Text('Your market, explained', style: AppText.body(12.5, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.entry, required this.selected, required this.badge, required this.onTap});
  final NavEntry entry;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      semanticLabel: entry.label,
      pressScale: 0.98,
      builder: (context, s) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.fromLTRB(0, 11, 12, 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.panelHi : (s.hover ? AppColors.panel : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: s.focus ? AppColors.text : Colors.transparent),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 3,
              height: selected ? 20 : 0,
              decoration: BoxDecoration(color: AppColors.brass, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 11),
            Icon(entry.icon, size: 20, color: selected ? AppColors.brass : AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.label,
                style: AppText.body(14.5,
                    color: selected ? AppColors.text : AppColors.muted,
                    w: selected ? FontWeight.w600 : FontWeight.w500),
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.bear, borderRadius: BorderRadius.circular(999)),
                child: Text('$badge', style: AppText.number(11.5, color: AppColors.ink)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SageCard extends StatelessWidget {
  const _SageCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A2031), AppColors.panel],
          ),
          border: Border.all(color: AppColors.brass.fade(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SageAvatar(size: 30),
                const SizedBox(width: 10),
                Expanded(child: Text('Stuck on something?', style: AppText.body(14, w: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 8),
            Text('Ask Sage about any coin, chart or word you don\'t know.',
                style: AppText.body(13, color: AppColors.muted)),
            const SizedBox(height: 12),
            AppButton(label: 'Ask Sage', icon: Icons.forum_rounded, compact: true, onTap: onTap),
          ],
        ),
      );
}
