import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../motion.dart';
import 'widgets/brand_header.dart';
import 'widgets/login_form.dart';

/// "One Enterprise" palette for the sign-in page. Local to this screen: the
/// sign-up page and the dashboard keep the app theme.
abstract final class OE {
  static const navy = Color(0xFF0E1036);
  static const button = Color(0xFF11143A);
  static const teal = Color(0xFF48C9C0);
  static const orange = Color(0xFFF2A53A);
  static const ink = Color(0xFF111827);
  static const body = Color(0xFF4B5563);
  static const muted = Color(0xFF6B7280);
  static const hint = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const fill = Color(0xFFF3F4F6);
  static const danger = Color(0xFFDC2626);
  static const link = Color(0xFF1E2A6B);
  static const accent = Color(0xFF1F4E79);

  static const mono = TextStyle(
    fontFamily: 'Consolas',
    fontFamilyFallback: ['Menlo', 'Courier New', 'monospace'],
  );
}

/// Split sign-in page: brand panel on the left, the stepped form on the right.
/// Below 900px the brand fills the screen first, and "Sign in" reveals the
/// form below a compact header.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    final pad = MediaQuery.sizeOf(context).height < 900 ? 12.0 : 24.0;

    if (narrow) {
      if (!_showForm) return _Splash(onSignIn: () => setState(_show));
      return Scaffold(
        backgroundColor: Colors.white,
        body: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 27, 18, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 532),
                      child: const LoginForm(compact: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final form = LayoutBuilder(
      builder: (context, box) => ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: pad),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - pad * 2),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 532),
                child: const LoginForm(),
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          children: [
            // 773 of 1680 in the mock.
            const Expanded(flex: 46, child: _BrandPanel()),
            Expanded(flex: 54, child: form),
          ],
        ),
      ),
    );
  }

  void _show() => _showForm = true;
}

/// Phone-only cover page, built to the design mock: a 390x578 artboard with
/// every element at its measured position, until "SIGN IN" reveals the form.
///
/// The artboard scales to the phone's width and stretches to its height: the
/// header stays at the top, the button and footer at the bottom, and the art
/// centres between them, so a phone taller than the mock has no empty band.
class _Splash extends StatelessWidget {
  const _Splash({required this.onSignIn});

  final VoidCallback onSignIn;

  static const _w = 390.0, _h = 578.0;

  /// The height the enlarged art needs between the headline and the button
  /// without touching either; shorter screens scale the page down to fit it.
  static const _minH = 612.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            // Flutter web's first frame arrives in a ~1.6px box, before the
            // real window size is known. Paint nothing until there is room.
            if (box.maxHeight < 200 || box.maxWidth < 200) {
              return const SizedBox.expand();
            }
            final scale = math.min(box.maxWidth / _w, box.maxHeight / _minH);
            return Center(
              child: SizedBox(
                width: _w * scale,
                height: box.maxHeight,
                child: FittedBox(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: _w,
                    height: box.maxHeight / scale,
                    child: _SplashArtboard(onSignIn: onSignIn),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The mock's elements at their measured positions, in logical pixels.
class _SplashArtboard extends StatelessWidget {
  const _SplashArtboard({required this.onSignIn});

  final VoidCallback onSignIn;

  static const _grey = Color(0xFF8A93A6);

  // Enlarged from the mock at the user's request: headline 27 -> 31, the
  // diagram by 12%, and the button raised 24.
  static const _headlineSize = 31.0;
  static const _headlineTop = 118.5;
  static const _headlineBottom = _headlineTop + 2 * _headlineSize * (30 / 27);
  static const _artScale = 1.12;
  static const _buttonBottom = 82.2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // The art, scaled about the hub, centres between the headline and the
      // button, however tall the screen is.
      const hub = _SplashHubPainter.hub;
      const artTop = 207.8, artBottom = 445.5; // card edges in the mock
      final top = hub.dy - (hub.dy - artTop) * _artScale;
      final bottom = hub.dy + (artBottom - hub.dy) * _artScale;
      final buttonTop = box.maxHeight - _buttonBottom - 48;
      final dy = (_headlineBottom + buttonTop) / 2 - (top + bottom) / 2;
      return Stack(
        children: [
          Positioned(
            left: 23.6,
            top: 27.9,
            child: Image.asset(
              'assets/stackly_logo.png',
              height: 34.9,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'Stackly',
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned(
            left: 24,
            top: 79,
            child: Text(
              // Broken by hand where the mock breaks it, so the wrap does not
              // depend on which monospace font the platform substitutes.
              'CLOUD PLATFORM  ·  HRMS  ·  CRM  ·  ERP  ·\nFINANCE  ·  AI',
              style: OE.mono.copyWith(
                fontSize: 9.5,
                letterSpacing: 1.95,
                height: 12 / 9.5,
                color: _grey,
              ),
            ),
          ),
          const Positioned(
            left: 25.5,
            top: _headlineTop,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'One identity.\n'),
                  TextSpan(
                    text: 'Infinite ',
                    style:
                        TextStyle(color: Color(0xFF4F7FF1), letterSpacing: .3),
                  ),
                  TextSpan(
                    text: 'Potential.',
                    style: TextStyle(letterSpacing: .3),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: _headlineSize,
                height: 30 / 27,
                fontWeight: FontWeight.w700,
                // Roboto's proportions differ from the mock's face, so each
                // line's spacing is set to match that line's measured width.
                letterSpacing: 1,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: dy,
            width: _Splash._w,
            height: _Splash._h,
            child: Transform.scale(
              scale: _artScale,
              alignment: Alignment(
                hub.dx / _Splash._w * 2 - 1,
                hub.dy / _Splash._h * 2 - 1,
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                      child: CustomPaint(painter: _SplashHubPainter())),
                  for (final c in _SplashHubPainter.cards)
                    Positioned.fromRect(
                      rect: c.rect,
                      child: _ModuleCard(c.icon, c.title, c.subtitle),
                    ),
                  Positioned(
                    left: _SplashHubPainter.hub.dx - 21.75,
                    top: _SplashHubPainter.hub.dy - 21.75,
                    child: Container(
                      width: 43.5,
                      height: 43.5,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF5E8BDC), Color(0xFF2C4C9C)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF3F6FE0).withValues(alpha: .45),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: const Text(
                        '1E',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 64.5,
            right: 65.2,
            bottom: _buttonBottom,
            height: 48,
            child: FilledButton(
              onPressed: onSignIn,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF142CD7),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'SIGN IN',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          for (final (x, word) in const [
            (25.2, 'Secure'),
            (77.8, 'Scalable'),
            (137.8, 'Future-Ready'),
          ])
            Positioned(
              left: x,
              bottom: 31.5,
              child: Text(
                word,
                style: const TextStyle(fontSize: 11.4, height: 1, color: _grey),
              ),
            ),
        ],
      );
    });
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1024),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF171D34)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 13.4,
            top: 12.7,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF16203D),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 17, color: const Color(0xFF7FA6F5)),
            ),
          ),
          Positioned(
            left: 14,
            top: 41.5,
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            left: 13.4,
            top: 58.6,
            child: Text(
              subtitle,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 8.3,
                height: 1.2,
                color: _SplashArtboard._grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _Card = ({Rect rect, IconData icon, String title, String subtitle});

/// The ring, and the spokes from the hub to each card's inner corner. The
/// cards and the hub tile are painted over it.
class _SplashHubPainter extends CustomPainter {
  const _SplashHubPainter();

  static const hub = Offset(194.8, 327.9);

  // Measured off the mock; the cards are not quite uniform there either.
  static final cards = <_Card>[
    (
      rect: const Rect.fromLTWH(33.8, 207.8, 114.8, 82),
      icon: Icons.person_outline,
      title: 'People',
      subtitle: 'Manage users & teams',
    ),
    (
      rect: const Rect.fromLTWH(243.8, 207.8, 103.5, 82),
      icon: Icons.layers_outlined,
      title: 'Applications',
      subtitle: 'Integrate & manage',
    ),
    (
      rect: const Rect.fromLTWH(39.8, 363.8, 109.5, 82),
      icon: Icons.shield_outlined,
      title: 'Security',
      subtitle: 'Protect every access',
    ),
    (
      rect: const Rect.fromLTWH(243.8, 363.8, 114, 82),
      icon: Icons.bar_chart_rounded,
      title: 'Analytics',
      subtitle: 'Turn data into insights',
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final spoke = Paint()
      ..strokeWidth = 1.5
      ..color = const Color(0xFF3A4668);
    final r = [for (final c in cards) c.rect];
    for (final corner in [
      r[0].bottomRight,
      r[1].bottomLeft,
      r[2].topRight,
      r[3].topLeft,
    ]) {
      canvas.drawLine(hub, corner, spoke);
    }

    canvas.drawCircle(
      hub,
      109.1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFF375AA8),
    );
  }

  @override
  bool shouldRepaint(_SplashHubPainter old) => false;
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final short = MediaQuery.sizeOf(context).height < 820;
    final hero = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _in(
            0,
            Text(
              'CLOUD PLATFORM · HRMS · CRM · ERP · FINANCE · AI',
              style: OE.mono.copyWith(
                fontSize: 13,
                letterSpacing: 3.2,
                color: OE.teal,
              ),
            )),
        const SizedBox(height: 22),
        _in(
            1,
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Every operation.\n'),
                  TextSpan(
                    text: 'One sign-in.',
                    style: TextStyle(color: OE.orange),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 52,
                height: 1.08,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: Colors.white,
              ),
            )),
        const SizedBox(height: 26),
        _in(
            2,
            SizedBox(
              width: 520,
              child: Text(
                'HR, sales, procurement, finance and your AI copilot — running '
                'on one identity, one policy, one audit trail.',
                style: TextStyle(
                  fontSize: 17.5,
                  height: 1.6,
                  color: Colors.white.withValues(alpha: .78),
                ),
              ),
            )),
        const SizedBox(height: 64),
        // Centred in the panel, as in the mock: the text column starts 65px
        // in, so shift the 480px diagram by the remaining gutter.
        _in(
            3,
            const SizedBox(
              width: 643,
              child: Center(
                child: SizedBox(width: 480, height: 180, child: _HubDiagram()),
              ),
            )),
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2062), Color(0xFF0F1242), Color(0xFF0B0D2C)],
          stops: [0, .45, 1],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 900 ? 24 : 65,
        vertical: short ? 26 : 46,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FadeIn(child: _Logo()),
          // Laid out at the mock's 1680x1050 size and scaled down to fit, so
          // a smaller window shrinks the art instead of re-flowing it.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: hero,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: .10)),
          SizedBox(height: short ? 20 : 34),
          _in(
              4,
              const Wrap(
                spacing: 34,
                runSpacing: 8,
                children: [
                  _Badge(Icons.shield_outlined, 'SOC 2 Type II'),
                  _Badge(Icons.lock_outline, 'ISO 27001'),
                  _Badge(Icons.schedule, '99.95% uptime SLA'),
                ],
              )),
        ],
      ),
    );
  }
}

/// Staggered entrance for the brand panel's pieces, in reading order.
Widget _in(int i, Widget child) => FadeIn(
      delay: Motion.stagger * (i + 1) * 2,
      duration: Motion.complex,
      offset: 14,
      child: child,
    );

/// Drives [_HubPainter] on a slow loop. Under reduced motion it holds still.
class _HubDiagram extends StatefulWidget {
  const _HubDiagram();

  @override
  State<_HubDiagram> createState() => _HubDiagramState();
}

class _HubDiagramState extends State<_HubDiagram>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
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
  Widget build(BuildContext context) => CustomPaint(painter: _HubPainter(_c));
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF2C94C), Color(0xFF8BD39A), Color(0xFF5BC6E0)],
            ),
          ),
          child: const Text(
            '1E',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: OE.navy,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'One Enterprise',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: .55);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 7),
        Text(label, style: OE.mono.copyWith(fontSize: 12.5, color: color)),
      ],
    );
  }
}

/// The AI hub diagram: three modules each side wired into the AI node. Live
/// integrations are solid teal, the rest dashed.
class _HubPainter extends CustomPainter {
  _HubPainter(this.t) : super(repaint: t);

  /// Loop progress, 0..1.
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final hub = Offset(w / 2, h / 2);
    const inset = 7.0;
    final rows = [8.0, h / 2, h - 8];

    final solid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0xFF3AA69B).withValues(alpha: .85);
    final dashed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF5A60B8).withValues(alpha: .85);

    Path curve(Offset from) {
      final dx = hub.dx - from.dx;
      return Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(
          from.dx + dx * .5,
          from.dy,
          hub.dx - dx * .2,
          hub.dy + (from.dy - hub.dy) * .35,
          hub.dx,
          hub.dy,
        );
    }

    // Left: HRMS, CRM solid; ERP dashed. Right: FINANCE solid; the rest dashed.
    final live = [
      curve(Offset(inset, rows[0])),
      Path()
        ..moveTo(inset, rows[1])
        ..lineTo(hub.dx, hub.dy),
      curve(Offset(w - inset, rows[0])),
    ];
    for (final p in live) {
      canvas.drawPath(p, solid);
    }
    final phase = t.value * 6; // one dash period per loop: dashes march inward
    _dash(canvas, curve(Offset(inset, rows[2])), dashed, phase);
    _dash(
        canvas,
        Path()
          ..moveTo(w - inset, rows[1])
          ..lineTo(hub.dx, hub.dy),
        dashed,
        phase);
    _dash(canvas, curve(Offset(w - inset, rows[2])), dashed, phase);

    // A signal travelling each live wire into the hub, staggered per wire.
    for (var i = 0; i < live.length; i++) {
      final p = (t.value + i / live.length) % 1;
      final m = live[i].computeMetrics().first;
      final at = m.getTangentForOffset(m.length * p)!.position;
      final fade = math.sin(p * math.pi); // appear and vanish at the ends
      canvas.drawCircle(
        at,
        6,
        Paint()
          ..color = OE.teal.withValues(alpha: .25 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
          at, 2.2, Paint()..color = OE.teal.withValues(alpha: fade));
    }

    final node = Paint()..color = const Color(0xFF3A3F9A);
    final nodeRing = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF6C72D8).withValues(alpha: .8);
    for (final y in rows) {
      for (final x in [inset, w - inset]) {
        canvas.drawCircle(Offset(x, y), 5.5, node);
        canvas.drawCircle(Offset(x, y), 5.5, nodeRing);
      }
    }

    const labels = [
      ('HRMS', 'FINANCE'),
      ('CRM', 'WORKFLOW'),
      ('ERP', 'ANALYTICS'),
    ];
    for (var i = 0; i < 3; i++) {
      _text(canvas, labels[i].$1, Offset(inset + 16, rows[i]), false);
      _text(canvas, labels[i].$2, Offset(w - inset - 63, rows[i]), true);
    }

    // The hub: soft breathing glow, orange ring, filled core, and a ripple
    // expanding outward once per loop.
    final breath = (math.sin(t.value * 2 * math.pi) + 1) / 2;
    canvas.drawCircle(
      hub,
      36 + 4 * breath,
      Paint()
        ..color = const Color(0xFF2F3590).withValues(alpha: .25 + .15 * breath),
    );
    canvas.drawCircle(
      hub,
      30 + 22 * t.value,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFC7773F).withValues(alpha: .5 * (1 - t.value)),
    );
    canvas.drawCircle(
      hub,
      30,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFC7773F).withValues(alpha: .7),
    );
    canvas.drawCircle(hub, 21, Paint()..color = const Color(0xFF2B2F7C));
    _text(canvas, 'AI', hub, null, color: const Color(0xFFB9BCF0));
  }

  void _dash(Canvas canvas, Path path, Paint paint, [double phase = 0]) {
    for (final m in path.computeMetrics()) {
      for (var d = phase - 6; d < m.length; d += 6) {
        canvas.drawPath(
            m.extractPath(math.max(d, 0), math.min(d + 3, m.length)), paint);
      }
    }
  }

  /// [alignEnd]: null centres on [at], true ends at it, false starts at it.
  void _text(Canvas canvas, String s, Offset at, bool? alignEnd,
      {Color color = const Color(0xFFA5A9D6)}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: 11.5, letterSpacing: .4, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = switch (alignEnd) {
      null => at.dx - tp.width / 2,
      true => at.dx - tp.width,
      false => at.dx,
    };
    tp.paint(canvas, Offset(x, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_HubPainter old) => old.t != t;
}
