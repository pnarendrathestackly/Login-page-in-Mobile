import 'package:flutter/material.dart';

import 'auth.dart';
import 'main.dart';
import 'router/app_router.dart';
import 'widgets.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, required this.controller});

  final AuthController controller;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agreed = true;

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      showToast(
        context,
        'Please accept the terms to continue',
        isError: true,
      );
      return;
    }
    final error = await widget.controller.register(
      name: '${_first.text.trim()} ${_last.text.trim()}',
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (error != null) {
      showToast(context, error, isError: true);
      return;
    }
    showToast(context, 'Account created. Please sign in.');
    // Toast lives in the root Overlay, so it survives this route change and
    // stays visible on the login screen.
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds so the Sign Up button reflects controller.busy.
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _form(context),
    );
  }

  Widget _form(BuildContext context) {
    return AuthScaffold(
      left: const AuthHero(
        title: ['Start', 'Your Learning'],
        image: 'assets/signup_art.jpg',
        highlight: 'Journey',
        subtitle: 'Create an account and be part\n'
            'of a community that learns,\n'
            'builds and grows together.',
      ),
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create Your Account',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fill in the details to get started.',
              style: TextStyle(fontSize: 15, color: kMuted),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AuthField(
                    hint: 'First name',
                    icon: Icons.person_outline,
                    controller: _first,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'First name is required'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthField(
                    hint: 'Last name',
                    icon: Icons.person_outline,
                    controller: _last,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Last name is required'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AuthField(
              hint: 'Email address',
              icon: Icons.mail_outline,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: emailValidator,
            ),
            const SizedBox(height: 14),
            AuthField(
              hint: 'Create a password',
              icon: Icons.lock_outline,
              controller: _password,
              obscure: true,
              validator: passwordValidator,
            ),
            const SizedBox(height: 14),
            AuthField(
              hint: 'Confirm password',
              icon: Icons.lock_outline,
              controller: _confirm,
              obscure: true,
              validator: (v) =>
                  v == _password.text ? null : 'Passwords do not match',
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreed,
                  activeColor: kIndigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 14, color: kInk),
                        children: [
                          TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(color: kIndigo),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(color: kIndigo),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Sign Up',
              loading: widget.controller.busy,
              loadingLabel: 'Creating account...',
              onTap: _submit,
            ),
            const SizedBox(height: 22),
            const OrDivider(label: 'Or sign up with'),
            const SizedBox(height: 18),
            const SocialRow(),
            const SizedBox(height: 16),
            FooterPrompt(
              text: 'Already have an account?',
              action: 'Login',
              onTap: () => context.go(AppRoutes.login),
            ),
          ],
        ),
      ),
    );
  }
}
