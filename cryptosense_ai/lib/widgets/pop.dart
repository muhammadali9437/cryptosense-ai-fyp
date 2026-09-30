import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'buttons.dart';

/// Opens a popup that blurs the page behind it and springs in gently.
Future<T?> showPop<T>(BuildContext context, {required Widget child, double maxWidth = 520}) {
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.fade(0.45),
    transitionDuration: Duration(milliseconds: reduceMotion ? 0 : 280),
    pageBuilder: (ctx, _, __) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6 * anim.value, sigmaY: 6 * anim.value),
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(curved), child: child),
        ),
      );
    },
  );
}

/// The card inside every popup: icon, title, close button, scrollable body, actions.
class PopCard extends StatelessWidget {
  const PopCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.leading,
    this.accent = AppColors.brass,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Color accent;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final lead = leading ??
        (icon == null
            ? null
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.fade(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 21),
              ));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(color: Colors.black.fade(0.5), blurRadius: 48, offset: const Offset(0, 24)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lead != null) ...[lead, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.display(18.5)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(subtitle!, style: AppText.body(13, color: AppColors.muted)),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
              child: child,
            ),
          ),
          if (actions.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: actions,
              ),
            ),
        ],
      ),
    );
  }
}

/// Yes/no popup. Returns true when the user confirms.
Future<bool> confirmPop(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Color color = AppColors.bear,
}) async {
  final result = await showPop<bool>(
    context,
    maxWidth: 420,
    child: Builder(
      builder: (ctx) => PopCard(
        title: title,
        icon: Icons.warning_amber_rounded,
        accent: color,
        actions: [
          AppButton(
            label: 'Cancel',
            kind: ButtonKind.ghost,
            color: AppColors.muted,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(label: confirmLabel, color: color, onTap: () => Navigator.of(ctx).pop(true)),
        ],
        child: Text(message, style: AppText.body(15, color: AppColors.muted)),
      ),
    ),
  );
  return result ?? false;
}

/// Small floating notification ("Alert created", "Limits saved", price alerts).
void toast(
  BuildContext context,
  String message, {
  Color color = AppColors.bull,
  IconData icon = Icons.check_circle_rounded,
}) {
  final wide = MediaQuery.sizeOf(context).width > 560;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: wide ? 420 : null,
        backgroundColor: AppColors.panelHi,
        elevation: 8,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.fade(0.5)),
        ),
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: AppText.body(14))),
          ],
        ),
      ),
    );
}
