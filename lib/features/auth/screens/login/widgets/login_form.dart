import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../auth.dart';
import '../../../../../main.dart';
import '../../../../../motion.dart';
import '../../../../../otp_field.dart';
import '../../../../../providers/auth_provider.dart';
import '../../../../../router/app_router.dart';
import '../../../../../widgets.dart';
import 'login_otp_field.dart';

/// Email, password and OTP in one form — the whole sign-in, with no second
/// screen and no `/otp` route. All state lives in [AuthProvider]; this widget
/// owns only its text controllers.
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otpKey = GlobalKey<OtpFieldState>();

  String _code = '';
  bool _remember = true;

  /// Set once the user submits, so the OTP box only turns red after an
  /// attempt rather than while the code is still being typed.
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    if (_code.length != OtpField.defaultLength) return;

    final auth = context.read<AuthProvider>();
    await auth.signInWithCode(
      email: _email.text,
      password: _password.text,
      code: _code,
    );
    if (!mounted) return;

    // Failed: clear only the code. Email and password stay, so a mistyped
    // digit does not cost the user the whole form.
    if (auth.status != AuthStatus.authenticated) {
      _otpKey.currentState?.clear();
      setState(() => _code = '');
    }
    // Success needs no navigation here: the guard in AppRouter reacts to the
    // auth state change and routes to the dashboard.
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds on auth changes only — the hero art beside this form does not.
    final auth = context.watch<AuthProvider>();
    final busy = auth.busy;
    final codeComplete = _code.length == OtpField.defaultLength;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your credentials and one-time password to sign in.',
            style: TextStyle(fontSize: 15, color: kMuted),
          ),
          ExpandFade(
            visible: auth.error != null,
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: AuthMessage(text: auth.error ?? '', isError: true),
            ),
          ),
          ExpandFade(
            visible: auth.notice != null,
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: AuthMessage(text: auth.notice ?? '', isError: false),
            ),
          ),
          const SizedBox(height: 28),
          AuthField(
            hint: 'Email address',
            icon: Icons.mail_outline,
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            validator: emailValidator,
          ),
          const SizedBox(height: 16),
          AuthField(
            hint: 'Password',
            icon: Icons.lock_outline,
            controller: _password,
            obscure: true,
            validator: passwordValidator,
          ),
          const SizedBox(height: 16),
          // Directly below the password, per spec — not a separate screen.
          LoginOtpField(
            otpKey: _otpKey,
            enabled: !busy,
            hasError: auth.error != null || (_submitted && !codeComplete),
            demoCode: auth.demoCode,
            onChanged: (v) => setState(() => _code = v),
            onCompleted: (_) => _submit(),
          ),
          ExpandFade(
            visible: _submitted && !codeComplete,
            child: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Enter the 6-digit code.',
                style: TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Wrap so "Forgot password?" drops below the checkbox on a narrow
          // screen rather than overflowing the row.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _remember,
                    activeColor: kIndigo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (v) => setState(() => _remember = v ?? false),
                  ),
                  const Text(
                    'Remember me',
                    style: TextStyle(fontSize: 14, color: kInk),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kIndigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Sign In',
            loading: busy,
            loadingLabel: 'Signing in...',
            onTap: _submit,
          ),
          const SizedBox(height: 24),
          const OrDivider(label: 'Or continue with'),
          const SizedBox(height: 20),
          const SocialRow(),
          const SizedBox(height: 20),
          FooterPrompt(
            text: "Don't have an account?",
            action: 'Sign up',
            // Routing is centralized: this reports intent, the router owns
            // the page stack.
            onTap: busy ? null : () => context.go(AppRoutes.register),
          ),
        ],
      ),
    );
  }
}
