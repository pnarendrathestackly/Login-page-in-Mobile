import 'dart:async';

import 'package:flutter/material.dart';

import 'main.dart';
import 'motion.dart';

/// Split-screen shell: illustration/copy on the left, form card on the right.
/// Below 900px the left panel is dropped and the form fills the screen.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.left, required this.form});

  final Widget left;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Container(
              margin: const EdgeInsets.all(24),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 40,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (!narrow) Expanded(child: left),
                  Expanded(
                    child: ScrollConfiguration(
                      // ponytail: keep scrolling for short windows, hide the bar.
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 40,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const FadeIn(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: NavLinks(),
                              ),
                            ),
                            const SizedBox(height: 36),
                            FadeIn(delay: Motion.stagger, child: form),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Left panel: brand mark, headline, subtitle and the illustration.
class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.highlight,
    this.image,
  });

  /// Lines rendered in near-black.
  final List<String> title;

  /// Optional final line rendered in indigo ("again!", "Journey").
  final String? highlight;
  final String subtitle;

  /// Drop a PNG in assets/ and pass its path to swap the placeholder art.
  final String? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEDEBFC), Color(0xFFDCD8F7)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 40, 32, 0),
            // Stagger applies to the three content blocks only — spacers are
            // outside it so they do not consume stagger slots and delay the
            // subtitle.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FadeIn(child: BrandMark()),
                const SizedBox(height: 48),
                FadeIn(
                  delay: Motion.stagger,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in title)
                        Text(
                          line,
                          style: const TextStyle(
                            fontSize: 40,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: kInk,
                          ),
                        ),
                      if (highlight != null)
                        Text(
                          highlight!,
                          style: const TextStyle(
                            fontSize: 40,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: kIndigo,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FadeIn(
                  delay: Motion.stagger * 2,
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.5,
                      color: kMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          Expanded(
            child: image == null
                // ponytail: placeholder art, swap for the real asset later.
                ? const _ArtPlaceholder()
                : Image.asset(
                    image!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.topCenter,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ArtPlaceholder extends StatelessWidget {
  const _ArtPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.auto_stories_rounded,
        size: 140,
        color: kIndigo.withValues(alpha: .25),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.school_rounded, color: kIndigo, size: 30),
        const SizedBox(width: 10),
        // Flexible so the mark survives a narrow container (e.g. the sidebar)
        // instead of overflowing.
        Flexible(
          child: Text(
            'TheStackly',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
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
    this.validator,
  });

  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      style: const TextStyle(fontSize: 15, color: kInk),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: kMuted, fontSize: 15),
        prefixIcon: Icon(widget.icon, size: 20, color: kMuted),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: kMuted,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
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
      height: 56,
      child: AnimatedContainer(
        duration: Motion.duration(context, Motion.standard),
        curve: Motion.standardCurve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: disabled
                ? const [Color(0xFFB9B2F2), Color(0xFFC9BCF7)]
                : const [Color(0xFF5B4BE1), Color(0xFF7C5CF0)],
          ),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: Text(
                    loading ? (widget.loadingLabel ?? 'Please wait...') : label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!loading) ...[
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
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
  const AuthMessage({super.key, required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFDC2626) : const Color(0xFF047857);
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
                child: Text(
                  text,
                  style: TextStyle(fontSize: 14, color: color),
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
  const SocialRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _SocialButton('Google', 'assets/google logo.png')),
        SizedBox(width: 12),
        Expanded(child: _SocialButton('GitHub', 'assets/github logo.png')),
        SizedBox(width: 12),
        Expanded(
          child: _SocialButton('Microsoft', 'assets/Microsoft-logo .png'),
        ),
      ],
    );
  }
}

class _SocialButton extends StatefulWidget {
  const _SocialButton(this.label, this.logo);

  final String label;
  final String logo;

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
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
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
              child: Image.asset(widget.logo, height: 32, fit: BoxFit.contain),
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
    final color =
        widget.isError ? const Color(0xFFDC2626) : const Color(0xFF047857);
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
                  color: Colors.white,
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
