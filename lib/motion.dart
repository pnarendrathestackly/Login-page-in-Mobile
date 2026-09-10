import 'package:flutter/material.dart';

/// Central animation vocabulary. Every animated surface pulls its timing and
/// curve from here so the app moves as one system rather than a pile of
/// independently-tuned transitions.
abstract final class Motion {
  // Durations, per the tiers in the brief.
  static const micro = Duration(milliseconds: 140); // hover, press, focus
  static const standard = Duration(milliseconds: 220); // panels, banners
  static const page = Duration(milliseconds: 320); // screen changes
  static const complex = Duration(milliseconds: 460); // staggered sequences

  /// Decelerating: things entering the screen.
  static const enter = Curves.easeOutCubic;

  /// Accelerating: things leaving.
  static const exit = Curves.easeInCubic;

  /// Symmetric: state changes on something already present.
  static const standardCurve = Curves.easeInOutCubic;

  /// Entrance offset. Small on purpose — movement reads as polish only while
  /// it stays under roughly 12px.
  static const enterOffset = 10.0;

  /// Gap between staggered siblings.
  static const stagger = Duration(milliseconds: 60);

  /// True when the OS asks for reduced motion. Every animated widget below
  /// checks this and renders the final state directly instead of animating.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Collapses a duration to zero under reduced motion, so an
  /// AnimatedContainer still applies state changes but does so instantly.
  static Duration duration(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Fade + rise entrance. Wrap anything that should animate in on first build.
///
/// Under reduced motion the child is returned as-is, so no animation runs and
/// no controller is created.
class FadeIn extends StatefulWidget {
  const FadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.standard,
    this.offset = Motion.enterOffset,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Vertical travel in logical pixels. Zero fades without moving.
  final double offset;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Motion.enter);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          // Transform + opacity only: no layout pass, so this stays cheap.
          offset: Offset(0, widget.offset * (1 - curved.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Lifts a card on hover and presses it on tap.
///
/// Pointer-driven effects are skipped on touch platforms, where there is no
/// hover state to reflect.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.onTap,
    this.lift = 2,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Upward travel on hover. Kept small so neighbouring content never shifts.
  final double lift;
  final BorderRadius? borderRadius;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final offset = reduced || !_hovered ? 0.0 : -widget.lift;
    final scale = !reduced && _pressed ? 0.985 : 1.0;

    return MouseRegion(
      cursor:
          widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: Motion.duration(context, Motion.micro),
          curve: Motion.standardCurve,
          child: AnimatedSlide(
            offset: Offset(0, offset / 100),
            duration: Motion.duration(context, Motion.micro),
            curve: Motion.standardCurve,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Vertical size + fade transition for content that appears in place, such as
/// a validation banner. Animating with a size transition keeps surrounding
/// content from jumping.
class ExpandFade extends StatelessWidget {
  const ExpandFade({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.duration(context, Motion.standard),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: AlignmentDirectional.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: visible ? child : const SizedBox.shrink(),
    );
  }
}
