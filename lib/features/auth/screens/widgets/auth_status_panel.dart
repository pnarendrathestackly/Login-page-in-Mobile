import 'package:flutter/material.dart';

import '../login/login_screen.dart' show OE;

/// The centred icon-and-message layout the auth outcome screens share:
/// a tinted round icon, a title, a body line, then stacked actions.
class AuthStatusPanel extends StatelessWidget {
  const AuthStatusPanel({
    super.key,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.body,
    this.callout,
    this.actions = const [],
    this.footer,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String title;

  /// The sentence under the title; rich so an address can be emphasised.
  final InlineSpan body;

  /// Optional tinted block between the body and the actions.
  final Widget? callout;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Center(
          child: Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
            child: Icon(icon, size: 27, color: iconColor),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -.4,
            color: OE.ink,
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.5, height: 1.55, color: OE.body),
        ),
        if (callout != null) ...[
          const SizedBox(height: 22),
          callout!,
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 28),
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            action,
          ],
        ],
        if (footer != null) ...[
          const SizedBox(height: 40),
          footer!,
        ],
      ],
    );
  }
}

/// Filled dark button, the primary action on these screens.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: OE.button,
          disabledBackgroundColor: OE.button.withValues(alpha: .55),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Outlined button, the secondary action on these screens.
class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: OE.ink,
          side: const BorderSide(color: OE.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
