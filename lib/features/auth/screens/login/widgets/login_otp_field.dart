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
            if (demoCode != null) ...[
              const SizedBox(width: 8),
              // Demo affordance only: a real backend never returns the code.
              Flexible(
                child: SelectableText(
                  'Demo: $demoCode',
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
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
