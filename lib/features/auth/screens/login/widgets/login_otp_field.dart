import 'package:flutter/material.dart';

import '../../../../../main.dart';
import '../../../../../otp_field.dart';

/// The OTP row on the login form: a label, the six boxes, and the demo-code
/// hint in debug builds.
///
/// ponytail: reuses the existing [OtpField] rather than writing a second OTP
/// widget. That one already handles paste, auto-advance, backspace and
/// numeric-only input; this adds only the labelling the login form needs.
class LoginOtpField extends StatelessWidget {
  const LoginOtpField({
    super.key,
    required this.otpKey,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
    this.onCompleted,
    this.demoCode,
  });

  final GlobalKey<OtpFieldState> otpKey;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;

  /// Debug-only: the code the demo backend generated, since this project has
  /// no mail/SMS service. Null in release and for any real backend.
  final String? demoCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 18, color: kMuted),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'One-time password',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kInk,
                ),
              ),
            ),
          ],
        ),
        // Demo affordance only: a real backend never returns the code, so this
        // whole block disappears the moment one is wired in. It is deliberately
        // prominent — there is no mail/SMS service here, and a hint small
        // enough to miss leaves the app impossible to sign into.
        if (demoCode != null) ...[
          const SizedBox(height: 8),
          _DemoCodeBanner(code: demoCode!),
        ],
        const SizedBox(height: 8),
        OtpField(
          key: otpKey,
          enabled: enabled,
          hasError: hasError,
          onChanged: onChanged,
          onCompleted: onCompleted,
        ),
      ],
    );
  }
}

/// Shows the code the demo backend generated, because this project has no way
/// to email or text one.
///
/// Debug builds only: [AuthController.demoCode] returns null under
/// `kReleaseMode`, so a shipped build never renders this.
class _DemoCodeBanner extends StatelessWidget {
  const _DemoCodeBanner({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF92400E)),
          const SizedBox(width: 8),
          const Text(
            'Demo code:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF92400E),
            ),
          ),
          const SizedBox(width: 8),
          // Selectable so the code can be copied rather than retyped.
          Expanded(
            child: SelectableText(
              code,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: Color(0xFF7C2D12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
