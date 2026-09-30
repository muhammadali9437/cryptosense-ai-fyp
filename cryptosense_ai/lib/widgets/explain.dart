import 'package:flutter/material.dart';

import '../services/guide_content.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'buttons.dart';
import 'pop.dart';
import 'tappable.dart';

/// Sage's avatar: a brass-to-orchid coin with a spark.
class SageAvatar extends StatelessWidget {
  const SageAvatar({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brass, AppColors.orchid],
          ),
        ),
        child: Icon(Icons.auto_awesome_rounded, size: size * 0.5, color: AppColors.ink),
      );
}

/// The lightbulb button. Tapping it opens Sage's explanation of [topic].
class ExplainButton extends StatelessWidget {
  const ExplainButton({super.key, required this.topic});
  final String topic;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Explain this',
      child: Tappable(
        onTap: () => showExplainer(context, topic),
        semanticLabel: 'Explain this',
        builder: (context, s) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: s.hover || s.focus ? AppColors.brass.fade(0.18) : Colors.transparent,
            border: Border.all(color: AppColors.brass.fade(s.focus ? 1 : 0.45)),
          ),
          child: const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.brass),
        ),
      ),
    );
  }
}

Future<void> showExplainer(BuildContext context, String topic) async {
  final e = GuideContent.explainers[topic];
  if (e == null) return;
  await showPop<void>(
    context,
    child: Builder(
      builder: (ctx) => PopCard(
        title: e.title,
        subtitle: 'Sage explains',
        leading: const SageAvatar(size: 40),
        actions: [AppButton(label: 'Got it', onTap: () => Navigator.of(ctx).pop())],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in e.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(p, style: AppText.body(15, height: 1.6)),
              ),
            if (e.tip != null) TipBox(e.tip!),
          ],
        ),
      ),
    ),
  );
}

/// Highlighted "tip" box used in popups and lessons.
class TipBox extends StatelessWidget {
  const TipBox(this.text, {super.key, this.icon = Icons.tips_and_updates_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.brass.fade(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.brass.fade(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.brass, size: 19),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: AppText.body(14, height: 1.5))),
          ],
        ),
      );
}
