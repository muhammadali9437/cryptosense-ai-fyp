import 'package:flutter/material.dart';

import '../services/app_scope.dart';
import '../services/guide_content.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'buttons.dart';
import 'explain.dart';
import 'pop.dart';

/// Welcome tour: four short steps where Sage introduces the app.
/// Opens automatically on first launch and from the "?" button in the top bar.
Future<void> showTour(BuildContext context) async {
  final app = context.app;
  await showPop<void>(context, maxWidth: 500, child: const _Tour());
  app.finishTour();
}

class _Tour extends StatefulWidget {
  const _Tour();

  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    const steps = GuideContent.tourSteps;
    final s = steps[_step];
    final last = _step == steps.length - 1;

    return PopCard(
      title: s.title,
      subtitle: 'Step ${_step + 1} of ${steps.length}',
      leading: _step == 0 ? const SageAvatar(size: 40) : null,
      icon: s.icon,
      actions: [
        if (_step > 0)
          AppButton(
            label: 'Back',
            kind: ButtonKind.ghost,
            color: AppColors.muted,
            onTap: () => setState(() => _step--),
          ),
        AppButton(
          label: last ? 'Start exploring' : 'Next',
          icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
          onTap: last ? () => Navigator.of(context).pop() : () => setState(() => _step++),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              s.body,
              key: ValueKey(_step),
              style: AppText.body(16, height: 1.6),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.only(right: 6),
                  width: i == _step ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i <= _step ? AppColors.brass : AppColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
