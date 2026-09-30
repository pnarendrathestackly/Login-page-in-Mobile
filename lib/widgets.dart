import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'motion.dart';

/// Split-screen shell: marketing panel on the left, form card on the right.
/// Below 900px the left panel is dropped and the form fills the screen.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.left, required this.form});

  final Widget left;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 900;
    // Matches the threshold the auth forms use, so the card and the form agree
    // about when space is tight. 980, not 820: the login form is tall enough
    // (both banners plus the OTP row) that a 900px viewport is already short
    // for it — a lower threshold left the button below the fold on 1440x900.
    final shortViewport = size.height < 980;

    final card = ScrollConfiguration(
      // ponytail: keep scrolling for short windows, hide the bar.
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: narrow ? 20 : 48,
          vertical: shortViewport ? 12 : 32,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeIn(
                  delay: Motion.stagger,
                  child: Container(
                    padding: EdgeInsets.all(shortViewport ? 24 : 40),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder),
                      // A soft lift, not a drop shadow: the card sits on a
                      // pale ground and only needs to separate from it.
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F1B2432),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: form,
                  ),
                ),
                // Legal footnote is chrome, not a sign-in control: on a
                // short viewport it is the first thing to go so the button
                // above it stays above the fold.
                if (!shortViewport) ...[
                  const SizedBox(height: 24),
                  const FadeIn(delay: Motion.stagger, child: AuthFootnote()),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: kCanvas,
      body: SafeArea(
        child: narrow
            ? card
            : Row(
                children: [
                  Expanded(child: left),
                  Expanded(child: card),
                ],
              ),
      ),
    );
  }
}

/// One selling point in the left panel: a round icon chip, a bold title and a
/// line of supporting copy.
class HeroFeature {
  const HeroFeature(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

/// Left panel: brand bar, headline, feature grid and the product screenshot.
class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.highlight,
    this.image,
    this.features = const [],
  });

  /// Headline lines, rendered in near-black.
  final List<String> title;

  /// Optional word tinted brand blue where it occurs in the first title line.
  final String? highlight;
  final String subtitle;

  /// Drop an image in assets/ and pass its path to swap the product art.
  final String? image;

  /// Selling points shown in a two-column grid under the subtitle.
  final List<HeroFeature> features;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final shortViewport = height < 820;
    // Below ~900 the copy block has to give up size, or it eats the space the
    // art needs and the panel overflows.
    final compact = height < 900;
    return Container(
      // Pale sky gradient — the marketing side reads lighter and airier than
      // the white form card beside it.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kSurface, kCanvasDeep],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(48, shortViewport ? 24 : 32, 40, 0),
            child: const FadeIn(child: BrandMark()),
          ),
          // No scroll view: the hero must never scroll. The copy block takes
          // the height it needs and the art absorbs whatever is left, so the
          // panel always fits its viewport exactly.
          //
          // The copy takes the height its content needs — squeezing it with a
          // flex overflowed the column. The art below takes whatever is left.
          Padding(
            padding: EdgeInsets.fromLTRB(48, shortViewport ? 24 : 40, 40, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stagger applies to the content blocks only — spacers sit
                // outside it so they do not consume stagger slots.
                FadeIn(
                  delay: Motion.stagger,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, line) in title.indexed)
                        _titleLine(line, i == 0 ? highlight : null, compact),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 10 : 14),
                FadeIn(
                  delay: Motion.stagger * 2,
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: compact ? 13 : 15,
                      height: 1.5,
                      color: kMuted,
                    ),
                  ),
                ),
                if (features.isNotEmpty) ...[
                  SizedBox(height: compact ? 18 : 32),
                  FadeIn(
                    delay: Motion.stagger * 3,
                    child: _FeatureGrid(features: features, compact: compact),
                  ),
                ],
              ],
            ),
          ),
          if (image != null)
            Expanded(
              // Symmetric padding on all four sides: full-bleed art ran off
              // the left and bottom edges of the panel. The artwork sits as a
              // framed, centred panel with the same gutter on every side, and
              // the left gutter matches the copy block's 48px so the art lines
              // up with the headline above it.
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  48,
                  compact ? 14 : 24,
                  48,
                  compact ? 20 : 32,
                ),
                child: FadeIn(
                  delay: Motion.stagger * 4,
                  child: _HeroArt(image: image!),
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  /// Renders one headline line, tinting [accent] blue where it occurs.
  Widget _titleLine(String line, String? accent, bool compact) {
    final base = TextStyle(
      fontSize: compact ? 25 : 30,
      height: 1.25,
      fontWeight: FontWeight.w800,
      color: kInkStrong,
    );
    final at = accent == null ? -1 : line.indexOf(accent);
    if (at < 0) return Text(line, style: base);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: line.substring(0, at)),
          TextSpan(text: accent, style: const TextStyle(color: kIndigo)),
          TextSpan(text: line.substring(at + accent!.length)),
        ],
      ),
    );
  }
}

/// Two-column feature grid. Falls back to one column when the panel is too
/// narrow for two tiles to sit side by side.
class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.features, this.compact = false});

  final List<HeroFeature> features;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 24.0;
        final columns = c.maxWidth < 420 ? 1 : 2;
        final width = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: compact ? 14 : 22,
          children: [
            for (final f in features)
              SizedBox(width: width, child: _FeatureTile(f, compact: compact)),
          ],
        );
      },
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile(this.feature, {this.compact = false});

  final HeroFeature feature;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: compact ? 30 : 34,
          width: compact ? 30 : 34,
          decoration: BoxDecoration(
            color: kSurface,
            shape: BoxShape.circle,
            border: Border.all(color: kBorder),
          ),
          child: Icon(feature.icon, size: compact ? 15 : 17, color: kIndigo),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feature.title,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                feature.body,
                style: TextStyle(
                  fontSize: compact ? 11.5 : 12,
                  height: 1.4,
                  color: kMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Product screenshot, cropped into a rounded panel that bleeds off the bottom
/// of the hero the way the reference layout does.
class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    // A framed panel, bordered on all four sides and inset from the hero's
    // edges by its parent's padding, so the art never runs off the left or
    // bottom of the screen.
    //
    // cover still fills that frame: the artwork is portrait (roughly 3:4) and
    // the frame is wide, so only a horizontal band of it can show. Which band
    // is the whole question — bottomCenter showed just the books and a shoe,
    // topCenter just the wall above.
    //
    // -0.45 puts the window a little above centre, which is where the figure's
    // head and torso sit in both hero images. Tune this one number if the art
    // is ever replaced — it is the crop's focal point, not a magic constant.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        // A soft lift so the framed art reads as a panel sitting on the hero
        // gradient rather than a flat cut-out.
        boxShadow: const [
          BoxShadow(
            color: Color(0x141B2432),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        // 1px inside the border so the image does not paint over it.
        borderRadius: BorderRadius.circular(15),
        child: SizedBox.expand(
          child: Image.asset(
            image,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.45),
          ),
        ),
      ),
    );
  }
}

/// Copyright and legal links under the form card.
class AuthFootnote extends StatelessWidget {
  const AuthFootnote({super.key});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12, color: kMuted);
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 6,
      children: [
        Text(
          '© 2030 TheStackly. All rights reserved.',
          style: style,
        ),
        Text('Privacy Policy', style: style),
        Text('Terms of Service', style: style),
      ],
    );
  }
}

/// The brand glyph: three stacked plates drawn in perspective.
///
/// "Stackly" is a stack, so the mark is one — rather than a generic hexagon.
/// Depth comes from the drawing itself: each plate is a flattened diamond, the
/// ones behind are smaller and dimmer, and every plate carries a lit top face
/// over a darker side wall. No image asset, so it stays crisp at any size and
/// recolours with the theme.
class BrandGlyph extends StatelessWidget {
  const BrandGlyph({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StackPainter()),
    );
  }
}

class _StackPainter extends CustomPainter {
  /// Plates from back to front: vertical offset, scale and colour. The back
  /// plates are lighter so the stack recedes.
  static const _plates = <(double, double, Color)>[
    (0.06, 0.80, Color(0xFF93B4FB)),
    (0.26, 0.90, Color(0xFF5B8DEF)),
    (0.46, 1.00, kIndigo),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Plate proportions, as fractions of the box.
    // Flatter plates sitting closer together: taller ones read as separate
    // floating diamonds rather than a stack.
    final plateW = w * 0.84;
    final plateH = h * 0.40;
    final wall = h * 0.07;

    for (final (dy, scale, color) in _plates) {
      final cx = w / 2;
      final cy = h * dy + plateH / 2;
      final pw = plateW * scale;
      final ph = plateH * scale;

      // Side wall first, so the top face paints over its upper edge.
      final side = Path()
        ..moveTo(cx - pw / 2, cy)
        ..lineTo(cx, cy + ph / 2)
        ..lineTo(cx + pw / 2, cy)
        ..lineTo(cx + pw / 2, cy + wall)
        ..lineTo(cx, cy + ph / 2 + wall)
        ..lineTo(cx - pw / 2, cy + wall)
        ..close();
      canvas.drawPath(
        side,
        Paint()..color = Color.lerp(color, const Color(0xFF0B1220), 0.35)!,
      );

      // Top face: a diamond, lit from the upper left.
      final top = Path()
        ..moveTo(cx, cy - ph / 2)
        ..lineTo(cx + pw / 2, cy)
        ..lineTo(cx, cy + ph / 2)
        ..lineTo(cx - pw / 2, cy)
        ..close();
      canvas.drawPath(
        top,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, 0.34)!, color],
          ).createShader(
            Rect.fromCenter(center: Offset(cx, cy), width: pw, height: ph),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StackPainter oldDelegate) => false;
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandGlyph(size: 28),
        const SizedBox(width: 10),
        // Flexible so the mark survives a narrow container (e.g. the sidebar)
        // instead of overflowing.
        Flexible(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: kInkStrong,
                // A touch of letter-spacing keeps the heavier weight from
                // looking cramped beside the glyph.
                letterSpacing: -0.2,
              ),
              children: [
                const TextSpan(text: 'The'),
                TextSpan(
                  text: 'Stackly',
                  style: TextStyle(
                    // Gradient-like depth on the word: the brand blue with a
                    // subtle shadow so it sits on the surface like the glyph.
                    color: kIndigo,
                    shadows: [
                      Shadow(
                        color: kIndigo.withValues(alpha: .28),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class NavLinks extends StatelessWidget {
  const NavLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Learn  •  Build  •  Grow',
      style: TextStyle(fontSize: 14, color: kMuted),
    );
  }
}

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.hint,
    required this.icon,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.label,
    this.trailing,
  });

  final String hint;
  final IconData icon;

  /// Caption above the field ("Username", "Password"). Null renders the field
  /// on its own, which is what the non-auth call sites want.
  final String? label;

  /// Sits opposite [label] on the label row — e.g. "Forgot Password?".
  final Widget? trailing;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final field = _field();
    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kInk,
                ),
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
        const SizedBox(height: 7),
        field,
      ],
    );
  }

  Widget _field() {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      style: const TextStyle(fontSize: 14, color: kInk),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: kMutedStrong, fontSize: 14),
        prefixIcon: Icon(widget.icon, size: 18, color: kMutedStrong),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: kMutedStrong,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
        filled: true,
        fillColor: kFieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: _border(kBorder),
        enabledBorder: _border(kBorder),
        focusedBorder: _border(kIndigo),
      ),
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c),
      );
}

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.loadingLabel,
  });

  final String label;

  /// Null disables the button — used while a request is in flight so a second
  /// submit cannot be queued.
  final VoidCallback? onTap;
  final bool loading;
  final String? loadingLabel;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final loading = widget.loading;
    final onTap = widget.onTap;
    final disabled = loading || onTap == null;
    final reduced = Motion.reduced(context);

    return AnimatedScale(
      // Press feedback only; hover is carried by the gradient shift below.
      scale: !reduced && _pressed && !disabled ? 0.98 : 1.0,
      duration: Motion.duration(context, Motion.micro),
      curve: Motion.standardCurve,
      child: Listener(
        onPointerDown: disabled ? null : (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: _body(context, label, loading, onTap, disabled),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    String label,
    bool loading,
    VoidCallback? onTap,
    bool disabled,
  ) {
    return SizedBox(
      height: 48,
      child: AnimatedContainer(
        duration: Motion.duration(context, Motion.standard),
        curve: Motion.standardCurve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          // Flat primary, not a gradient: the enterprise theme carries weight
          // with colour and border, not decoration.
          color: disabled ? kPrimaryMuted : kIndigo,
        ),
        child: ElevatedButton(
          onPressed: disabled ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: AnimatedSwitcher(
            // Crossfades label <-> spinner so the loading state does not snap.
            duration: Motion.duration(context, Motion.standard),
            switchInCurve: Motion.enter,
            switchOutCurve: Motion.exit,
            child: Row(
              key: ValueKey(loading),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading) ...[
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kOnPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: Text(
                    loading ? (widget.loadingLabel ?? 'Please wait...') : label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kOnPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline banner for auth errors and confirmations. Pairs an icon with the
/// text so status is never carried by colour alone.
class AuthMessage extends StatelessWidget {
  const AuthMessage({
    super.key,
    required this.text,
    required this.isError,
    this.detail,
  });

  final String text;
  final bool isError;

  /// Smaller second line under [text], e.g. "2 attempts remaining before
  /// lockout."
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final color = isError ? kDanger : kSuccess;
    return FadeIn(
      duration: Motion.standard,
      offset: 6,
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            detail == null ? FontWeight.w400 : FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        detail!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: color.withValues(alpha: .85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: kBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: kMuted),
          ),
        ),
        const Expanded(child: Divider(color: kBorder)),
      ],
    );
  }
}

class SocialRow extends StatelessWidget {
  const SocialRow({super.key, this.compact = false});

  /// Shorter buttons for short viewports. The providers stay available —
  /// removing sign-in options to save space would cost a user their only way
  /// in — they simply take less vertical room.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            'Google',
            'assets/google logo.png',
            compact: compact,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            'GitHub',
            'assets/github logo.png',
            compact: compact,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            'Microsoft',
            'assets/Microsoft-logo .png',
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatefulWidget {
  const _SocialButton(this.label, this.logo, {this.compact = false});

  final String label;
  final String logo;
  final bool compact;

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        // Logo-only buttons need a clearer hover cue than a border tint alone.
        scale: !reduced && _hovered ? 1.03 : 1.0,
        duration: Motion.duration(context, Motion.micro),
        curve: Motion.standardCurve,
        child: OutlinedButton(
          // No identity provider is configured (the backend has no OAuth
          // integration), so say so rather than do nothing.
          onPressed: () => showToast(
            context,
            "${widget.label} sign-in isn't set up yet. Use your email "
            'address instead.',
            isError: true,
          ),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: widget.compact ? 8 : 14),
            side: BorderSide(color: _hovered ? kIndigo : kBorder),
            backgroundColor:
                _hovered ? kIndigo.withValues(alpha: .04) : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            animationDuration: Motion.duration(context, Motion.micro),
          ),
          child: Tooltip(
            message: widget.label,
            child: Semantics(
              label: 'Continue with ${widget.label}',
              button: true,
              child: Image.asset(
                widget.logo,
                height: widget.compact ? 22 : 32,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Footer such as "Don't have an account? Sign up".
class FooterPrompt extends StatelessWidget {
  const FooterPrompt({
    super.key,
    required this.text,
    required this.action,
    required this.onTap,
  });

  final String text;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Wrap, not Row: on a narrow screen the action drops to its own line
    // instead of overflowing.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: const TextStyle(fontSize: 14, color: kMuted)),
        TextButton(
          onPressed: onTap,
          child: Text(
            action,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kIndigo,
            ),
          ),
        ),
      ],
    );
  }
}

/// Top-right toast. Flutter's SnackBar is bottom-anchored and cannot be moved
/// there, so this rides the Overlay instead.
void showToast(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  // rootOverlay: the toast must outlive a route that pops right after showing
  // it (e.g. sign-up returning to login).
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Toast(
      message: message,
      isError: isError,
      duration: duration,
      onDismissed: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.isError,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final bool isError;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.standard,
  );
  Timer? _timer;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduced motion: appear at once, no slide, but still auto-dismiss.
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return widget.onDismissed();
    if (Motion.reduced(context)) return widget.onDismissed();
    await _c.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isError ? kDanger : kSuccess;
    final media = MediaQuery.of(context);
    return Positioned(
      top: media.padding.top + 56,
      right: 16,
      // Keeps the toast from spanning a wide desktop window.
      width: media.size.width < 420 ? media.size.width - 32 : 360,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, -.4),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _c, curve: Motion.enter)),
        child: FadeTransition(
          opacity: _c,
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: kSurfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: .35)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 18,
                      color: color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(fontSize: 14, color: kInk),
                      ),
                    ),
                    InkWell(
                      onTap: _dismiss,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 16, color: kMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared email/password rules used by both forms.
String? emailValidator(String? v) {
  final value = (v ?? '').trim();
  if (value.isEmpty) return 'Email is required';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
    return 'Enter a valid email address';
  }
  return null;
}

String? passwordValidator(String? v) {
  final value = v ?? '';
  if (value.isEmpty) return 'Password is required';
  if (value.length < 8) return 'Use at least 8 characters';
  return null;
}
