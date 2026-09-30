import 'dart:async';

import 'package:flutter/material.dart';

import '../../../router/app_router.dart';
import 'login/login_screen.dart' show OE;
import 'widgets/auth_status_panel.dart';

/// Shown in place of the sign-in form once an account is locked out, with a
/// live countdown to when it unlocks.
///
/// Presentation only: the lock itself is held by the backend, so closing this
/// screen or reloading the app does not lift it.
class AccountLockedPanel extends StatefulWidget {
  const AccountLockedPanel({
    super.key,
    required this.email,
    required this.lockedUntil,
    required this.onBack,
    required this.onReset,
  });

  final String email;
  final DateTime lockedUntil;

  /// Returns to the sign-in form — called on its own when the lock expires.
  final VoidCallback onBack;
  final VoidCallback onReset;

  @override
  State<AccountLockedPanel> createState() => _AccountLockedPanelState();
}

class _AccountLockedPanelState extends State<AccountLockedPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining == Duration.zero) {
        _ticker?.cancel();
        // The lock has lifted: send them back to try again.
        widget.onBack();
        return;
      }
      setState(() {});
    });
  }

  Duration get _remaining {
    final left = widget.lockedUntil.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _remaining;
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');

    return AuthStatusPanel(
      icon: Icons.lock_outline,
      tint: const Color(0xFFFDE4E4),
      iconColor: const Color(0xFFDC2626),
      title: 'This account is locked',
      body: TextSpan(
        children: [
          const TextSpan(text: 'Too many failed attempts. '),
          TextSpan(
            text: widget.email,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: OE.ink,
            ),
          ),
          const TextSpan(text: ' is locked for 15 minutes.'),
        ],
      ),
      callout: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF3E2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.schedule,
              size: 18,
              color: Color(0xFFB4741B),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Try again in $mm:$ss',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A5A14),
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Or reset your password now.',
                    style: TextStyle(fontSize: 13.5, color: Color(0xFFA06C1E)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        AuthPrimaryButton(label: 'Reset password', onTap: widget.onReset),
        AuthSecondaryButton(label: 'Back to sign in', onTap: widget.onBack),
      ],
      footer: Wrap(
        alignment: WrapAlignment.center,
        children: [
          const Text(
            'Recorded in the security audit log · ',
            style: TextStyle(fontSize: 13, color: OE.muted),
          ),
          InkWell(
            onTap: () => context.go(AppRoutes.forgotPassword),
            child: const Text(
              'Contact support',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OE.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
