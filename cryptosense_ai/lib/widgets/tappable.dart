import 'package:flutter/material.dart';

/// Hover / keyboard-focus / pressed state passed to a [Tappable] builder.
class TapState {
  const TapState(this.hover, this.focus, this.down);
  final bool hover, focus, down;
}

/// The one interactive primitive used by every custom button, row and chip.
/// Gives mouse hover, keyboard focus (Tab + Enter/Space), a soft press-in
/// scale, and respects the system "reduce motion" setting.
class Tappable extends StatefulWidget {
  const Tappable({
    super.key,
    required this.builder,
    this.onTap,
    this.semanticLabel,
    this.pressScale = 0.97,
  });

  final Widget Function(BuildContext context, TapState state) builder;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double pressScale;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _hover = false, _focus = false, _down = false;

  void _set(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => _set(() => _hover = v),
        onShowFocusHighlight: (v) => _set(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _set(() => _down = true) : null,
          onTapUp: enabled ? (_) => _set(() => _down = false) : null,
          onTapCancel: enabled ? () => _set(() => _down = false) : null,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down && !reduceMotion ? widget.pressScale : 1,
            duration: const Duration(milliseconds: 110),
            child: widget.builder(context, TapState(_hover, _focus, _down)),
          ),
        ),
      ),
    );
  }
}
