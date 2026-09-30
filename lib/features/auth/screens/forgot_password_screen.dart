import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../router/app_router.dart';
import '../../../widgets.dart';
import '../../../widgets/common/dialogs.dart';
import 'login/login_screen.dart' show OE;
import 'login/widgets/brand_header.dart';
import 'widgets/auth_status_panel.dart';

/// "Forgot your password?" — asks for the work email, then hands over to the
/// existing reset-code dialog.
///
/// The reply is deliberately the same whether or not the address is
/// registered, so this page cannot be used to discover who has an account.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final email = _email.text.trim();

    final error = await auth.requestPasswordReset(email);
    if (!mounted) return;
    if (error != null) {
      showToast(context, error, isError: true);
      return;
    }
    setState(() => _sent = true);
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    final error = await auth.requestPasswordReset(_email.text.trim());
    if (!mounted) return;
    showToast(
      context,
      error ?? 'Reset link sent again.',
      isError: error != null,
    );
  }

  /// The second stage: the code from the email plus the new password.
  Future<void> _enterCode() async {
    final auth = context.read<AuthProvider>();
    final email = _email.text.trim();
    // Demo builds cannot email the code, so it is shown in the dialog.
    final demo = auth.demoCode;
    final done = await showFormDialog(
      context,
      title: 'Choose a new password',
      subtitle: demo == null
          ? 'Enter the code sent to $email and your new password.'
          : 'Enter the reset code and your new password. Demo build: no '
              'email is sent — use code $demo.',
      submitLabel: 'Reset password',
      busyLabel: 'Resetting...',
      fields: [
        const FormFieldSpec(
          label: 'Reset code',
          icon: Icons.pin_outlined,
          keyboardType: TextInputType.number,
        ),
        const FormFieldSpec(
          label: 'New password',
          icon: Icons.lock_reset_outlined,
          obscure: true,
          validator: passwordValidator,
        ),
        const FormFieldSpec(
          label: 'Confirm new password',
          icon: Icons.lock_reset_outlined,
          obscure: true,
        ),
      ],
      onSubmit: (v) async {
        if (v['New password'] != v['Confirm new password']) {
          return 'The new passwords do not match.';
        }
        return auth.resetPassword(email, v['Reset code']!, v['New password']!);
      },
    );
    if (done == null || !mounted) return;
    showToast(
      context,
      'Password changed successfully. Sign in with your new password.',
    );
    if (mounted) context.go(AppRoutes.login);
  }

  /// Shown once the link is on its way. Deliberately identical whether or not
  /// the address is registered.
  Widget _sentPanel(bool busy) {
    return AuthStatusPanel(
      icon: Icons.mail_outline,
      tint: const Color(0xFFDCF5E6),
      iconColor: const Color(0xFF2E9E5B),
      title: 'Check your email',
      body: TextSpan(
        children: [
          const TextSpan(text: "We've sent a password reset link to "),
          TextSpan(
            text: _email.text.trim(),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: OE.ink,
            ),
          ),
          const TextSpan(text: '. The link expires in 30 minutes.'),
        ],
      ),
      actions: [
        AuthSecondaryButton(
          label: 'Resend email',
          onTap: busy ? null : _resend,
        ),
        AuthPrimaryButton(
          label: 'Back to sign in',
          onTap: busy ? null : () => context.go(AppRoutes.login),
        ),
        // Demo builds cannot deliver mail, so the code is entered here.
        AuthSecondaryButton(
          label: 'Enter reset code',
          onTap: busy ? null : _enterCode,
        ),
      ],
      footer: Wrap(
        alignment: WrapAlignment.center,
        children: [
          const Text(
            "Didn't get it? Check spam, or ",
            style: TextStyle(fontSize: 13.5, color: OE.muted),
          ),
          InkWell(
            onTap: busy ? null : _contactSupport,
            child: const Text(
              'contact support',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: OE.accent,
              ),
            ),
          ),
          const Text('.', style: TextStyle(fontSize: 13.5, color: OE.muted)),
        ],
      ),
    );
  }

  Future<void> _contactSupport() => showDetailDialog(
        context,
        title: 'Contact support',
        subtitle: 'Have your workspace name ready when you get in touch.',
        fields: const {
          'Email': 'support@oneenterprise.io',
          'Phone': '+1 (555) 010-0100',
          'Hours': '24/7 for sign-in issues',
        },
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final narrow = MediaQuery.sizeOf(context).width < 900;

    final form = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 532),
            child: _body(auth.busy),
          ),
        ),
      ),
    );

    if (narrow) {
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
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 532),
                      child: _body(auth.busy),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          children: [
            const Expanded(flex: 46, child: BrandHeader(tall: true)),
            Expanded(flex: 54, child: SafeArea(child: form)),
          ],
        ),
      ),
    );
  }

  Widget _body(bool busy) {
    if (_sent) return _sentPanel(busy);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: busy ? null : () => context.go(AppRoutes.login),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, size: 20, color: OE.muted),
                    SizedBox(width: 2),
                    Text(
                      'Back to sign in',
                      style: TextStyle(fontSize: 15, color: OE.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'PASSWORD RECOVERY',
            style: OE.mono.copyWith(
              fontSize: 11.5,
              letterSpacing: 2.2,
              color: OE.muted,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Forgot your password?',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
              color: OE.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter your work email and we'll send you a link to reset it.",
            style: TextStyle(fontSize: 15, height: 1.45, color: OE.body),
          ),
          const SizedBox(height: 26),
          const Text(
            'Work email',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OE.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            validator: emailValidator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (_) => busy ? null : _send(),
            style: const TextStyle(fontSize: 15, color: OE.ink),
            decoration: const InputDecoration(
              hintText: 'you@acmecorp.com',
              hintStyle: TextStyle(fontSize: 15, color: OE.hint),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: OE.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: OE.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: OE.button, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: busy ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: OE.button,
                disabledBackgroundColor: OE.button.withValues(alpha: .55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Send reset link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 56),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              const Text(
                'Remembered it? ',
                style: TextStyle(fontSize: 14.5, color: OE.body),
              ),
              InkWell(
                onTap: busy ? null : () => context.go(AppRoutes.login),
                child: const Text(
                  'Sign in',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: OE.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
