import 'dart:math' as math;

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

  /// Endless decorative loops (the login hub diagram). Tests switch this off
  /// in test/flutter_test_config.dart, since a loop never lets
  /// pumpAndSettle settle.
  static bool ambient = true;

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
  // The delay is folded into the controller (see the Interval below) rather
  // than a timer, so nothing is left pending if the widget is disposed early.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  late final _curved = CurvedAnimation(
    parent: _c,
    curve: Interval(
      widget.delay.inMicroseconds / _c.duration!.inMicroseconds,
      1,
      curve: Motion.enter,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = _curved;
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

/// Wraps each content child of a form column in a [FadeIn], one stagger step
/// apart, so a screen assembles in reading order. Spacers pass through
/// untouched. Wrapping every child keeps positional matching the same as the
/// bare column, so field state survives rebuilds; give the column a key that
/// changes per step to replay the sequence.
List<Widget> staggerIn(List<Widget> children, {int maxSteps = 8}) {
  var n = 0;
  return [
    for (final child in children)
      if (child is SizedBox && child.child == null)
        child
      else
        FadeIn(
          delay: Motion.stagger * math.min(n++, maxSteps),
          duration: Motion.page,
          child: child,
        ),
  ];
}

/// Scale-and-fade pop for a confirmation mark: overshoots slightly, then
/// settles. Under reduced motion the child is shown at its final state.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    final total = delay + Motion.complex;
    final start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, v, child) {
        final t = v <= start ? 0.0 : (v - start) / (1 - start);
        return Opacity(
          opacity: Curves.easeOut.transform(t),
          child: Transform.scale(
            scale: .6 + .4 * Curves.easeOutBack.transform(t),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Slow drifting light behind a dark brand surface: two soft glows on
/// independent paths and a few twinkling points. Paints nothing under reduced
/// motion or when [Motion.ambient] is off, leaving the surface as designed.
class AmbientGlow extends StatefulWidget {
  const AmbientGlow({super.key, required this.child});

  final Widget child;

  @override
  State<AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<AmbientGlow>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context) || !Motion.ambient) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_c.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _GlowPainter(_c)),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  static const _stars = [
    Offset(.82, .18),
    Offset(.64, .42),
    Offset(.91, .66),
    Offset(.48, .12),
    Offset(.74, .86),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final a = t.value * 2 * math.pi;
    final r = size.shortestSide * .9;

    void glow(Offset c, Color color) => canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ).createShader(Rect.fromCircle(center: c, radius: r)),
        );

    glow(
      Offset(
        size.width * (.78 + .14 * math.cos(a)),
        size.height * (.35 + .25 * math.sin(a)),
      ),
      const Color(0xFF4F7FF1).withValues(alpha: .20),
    );
    glow(
      Offset(
        size.width * (.30 + .18 * math.sin(a + 1.3)),
        size.height * (.95 + .2 * math.cos(2 * a)),
      ),
      const Color(0xFF6C4FE0).withValues(alpha: .14),
    );

    for (final (i, s) in _stars.indexed) {
      final tw = (math.sin(a * 3 + i * 1.7) + 1) / 2;
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        .8 + .7 * tw,
        Paint()..color = Colors.white.withValues(alpha: .15 + .45 * tw),
      );
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t;
}
