import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'tappable.dart';

enum ButtonKind { primary, ghost }

/// Brass-filled primary button or outlined ghost button.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.kind = ButtonKind.primary,
    this.color = AppColors.brass,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final ButtonKind kind;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, s) {
        final primary = kind == ButtonKind.primary;
        final bg = primary
            ? (s.hover ? Color.lerp(color, Colors.white, 0.14)! : color)
            : (s.hover ? color.fade(0.12) : Colors.transparent);
        final fg = primary ? AppColors.ink : color;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: compact ? 8 : 12),
          decoration: BoxDecoration(
            color: onTap == null ? AppColors.line : bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: s.focus ? AppColors.text : (primary ? color : color.fade(0.45)),
              width: s.focus ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 16 : 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(label, style: AppText.body(compact ? 13 : 14, color: fg, w: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}

/// Segmented selector (timeframes, filters). Scrolls sideways on small screens.
class SegmentPills extends StatelessWidget {
  const SegmentPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labels = const {},
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              Tappable(
                onTap: () => onChanged(o),
                semanticLabel: labels[o] ?? o,
                builder: (context, s) {
                  final on = o == selected;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: on ? AppColors.brass : (s.hover ? AppColors.panelHi : Colors.transparent),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: s.focus ? AppColors.text : Colors.transparent),
                    ),
                    child: Text(
                      labels[o] ?? o,
                      style: AppText.body(13, color: on ? AppColors.ink : AppColors.muted, w: FontWeight.w600),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
