import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_scope.dart';
import '../services/guide_content.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/bits.dart';
import '../widgets/buttons.dart';
import '../widgets/explain.dart';
import '../widgets/panel.dart';
import '../widgets/pop.dart';
import '../widgets/tappable.dart';

/// Academy: a numbered learning path that teaches how the market moves.
class AcademyScreen extends StatelessWidget {
  const AcademyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        const lessons = GuideContent.lessons;
        final done = lessons.where((l) => app.doneLessons.contains(l.id)).length;
        return PageBody(maxWidth: 980, children: [
          Panel(
            title: 'Your learning path',
            subtitle: '$done of ${lessons.length} lessons done. Each one takes about five minutes.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: done / lessons.length,
                    minHeight: 8,
                    backgroundColor: AppColors.line,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SageAvatar(size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        done == lessons.length
                            ? 'You finished every lesson. Keep practising by reading my market read on the Overview each day.'
                            : 'Go in order: each lesson builds on the one before. When something is unclear, tap "Ask Sage about this" inside the lesson.',
                        style: AppText.body(14.5, height: 1.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          for (var i = 0; i < lessons.length; i++)
            _LessonRow(index: i, lesson: lessons[i], done: app.doneLessons.contains(lessons[i].id)),
        ]);
      },
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.index, required this.lesson, required this.done});
  final int index;
  final Lesson lesson;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: () => showLesson(context, lesson),
      semanticLabel: lesson.title,
      pressScale: 0.99,
      builder: (context, s) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: s.hover ? AppColors.panelHi : AppColors.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: s.focus ? AppColors.text : (s.hover ? AppColors.brass.fade(0.4) : AppColors.line),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.bull.fade(0.15) : AppColors.ink,
                border: Border.all(color: done ? AppColors.bull : AppColors.brass.fade(0.5)),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, color: AppColors.bull)
                  : Text('${index + 1}', style: AppText.display(17, color: AppColors.brass)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.title, style: AppText.display(16.5)),
                  const SizedBox(height: 3),
                  Text(lesson.summary, style: AppText.body(14, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Tag(lesson.level, color: lesson.level == 'Beginner' ? AppColors.bull : AppColors.calm),
                      Tag('${lesson.minutes} min read'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(lesson.icon, color: AppColors.faint, size: 26),
          ],
        ),
      ),
    );
  }
}

Future<void> showLesson(BuildContext context, Lesson lesson) {
  final app = context.app;
  final market = context.market;
  return showPop<void>(
    context,
    maxWidth: 680,
    child: Builder(
      builder: (ctx) => ListenableBuilder(
        listenable: app,
        builder: (ctx, _) {
          final done = app.doneLessons.contains(lesson.id);
          return PopCard(
            title: lesson.title,
            subtitle: '${lesson.level}, about ${lesson.minutes} minutes',
            icon: lesson.icon,
            actions: [
              AppButton(
                label: 'Ask Sage about this',
                icon: Icons.forum_rounded,
                kind: ButtonKind.ghost,
                onTap: () {
                  Navigator.of(ctx).pop();
                  app.go(8);
                  app.ask(lesson.askPrompt, market);
                },
              ),
              AppButton(
                label: done ? 'Done' : 'Mark as done',
                icon: Icons.check_rounded,
                kind: done ? ButtonKind.ghost : ButtonKind.primary,
                color: done ? AppColors.bull : AppColors.brass,
                onTap: done
                    ? null
                    : () {
                        app.completeLesson(lesson.id);
                        toast(ctx, 'Lesson done: ${lesson.title}');
                        Navigator.of(ctx).pop();
                      },
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in lesson.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(p, style: AppText.body(16, height: 1.7)),
                  ),
                const SizedBox(height: 4),
                TipBox('Key takeaway: ${lesson.takeaway}', icon: Icons.bookmark_outline_rounded),
              ],
            ),
          );
        },
      ),
    ),
  );
}
