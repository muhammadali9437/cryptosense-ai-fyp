import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'explain.dart';

/// Standard content panel with an optional heading, action and lightbulb.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.explain,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final String? explain; // topic key in GuideContent.explainers
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            LayoutBuilder(builder: (context, box) {
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title!, style: AppText.display(17)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(subtitle!, style: AppText.body(13.5, color: AppColors.muted)),
                    ),
                ],
              );
              final help = explain == null ? null : ExplainButton(topic: explain!);
              if (trailing == null || box.maxWidth >= 560) {
                return Row(
                  children: [
                    Expanded(child: heading),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      // Flexible gives scrollable pills a bounded width.
                      Flexible(child: Align(alignment: Alignment.centerRight, child: trailing!)),
                    ],
                    if (help != null) ...[const SizedBox(width: 10), help],
                  ],
                );
              }
              // Narrow screens: action goes under the heading.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Expanded(child: heading), if (help != null) help]),
                  const SizedBox(height: 12),
                  trailing!,
                ],
              );
            }),
            const SizedBox(height: 18),
          ],
          child,
        ],
      ),
    );
  }
}

/// Scrollable page wrapper with responsive padding and a max width.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1320});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return SingleChildScrollView(
      padding: EdgeInsets.all(narrow ? 16 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 20),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Two columns on wide screens (2:1 by default), stacked on narrow ones.
class TwoColumn extends StatelessWidget {
  const TwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.breakpoint = 1080,
    this.leftFlex = 2,
    this.rightFlex = 1,
  });

  final Widget left, right;
  final double breakpoint;
  final int leftFlex, rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= breakpoint) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 20),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 20), right],
      );
    });
  }
}

/// Lays children out in a responsive grid of equal-width tiles.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.minTileWidth = 300, this.gap = 16});
  final List<Widget> children;
  final double minTileWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cols = (box.maxWidth / minTileWidth).floor().clamp(1, 4);
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    });
  }
}
