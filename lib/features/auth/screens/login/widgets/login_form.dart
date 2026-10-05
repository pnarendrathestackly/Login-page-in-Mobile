import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../auth.dart';
import '../../../../../motion.dart';
import '../../../../../otp_field.dart';
import '../../../../../providers/auth_provider.dart';
import '../../../../../router/app_router.dart';
import '../../../../../widgets.dart';
import '../../../../../widgets/common/dialogs.dart';
import '../../account_locked_screen.dart';
import '../login_screen.dart';
import 'login_otp_field.dart';

/// Three-step sign-in: identify (workspace + email), authenticate (password),
/// verify (OTP). Steps 1-2 are local; step 3 is simply "the backend is
/// awaiting a code", so it is read from [AuthProvider] rather than tracked here.
class LoginForm extends StatefulWidget {
  const LoginForm({super.key, this.compact = false});

  /// Phone layout under the brand header: the smaller type and tighter
  /// spacing of the phone sign-in mock. Desktop keeps the full-size form.
  final bool compact;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _workspace = TextEditingController(text: 'acmecorp');

  /// Set when the backend does not know the workspace; shown under the field
  /// until it is edited.
  String? _workspaceError;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otpKey = GlobalKey<OtpFieldState>();

  int _step = 0;

  /// When the code now outstanding was issued, and a 1s ticker so the
  /// "expires in" countdown stays live. Both are null off the verify step.
  DateTime? _codeIssuedAt;
  Timer? _ticker;

  /// Set once the code is accepted, so "You're in" is shown for a beat before
  /// the router swaps in the dashboard.
  bool _succeeded = false;
  // ponytail: not sent — the demo backend has no trusted-device store.
  bool _rememberDevice = true;

  /// Laptop-height windows: the mock is 1050px tall, so shrink the gaps
  /// rather than make the user scroll to the button.
  bool _tight = false;
  double _gap(double v) => _tight ? (v * .55).roundToDouble() : v;

  bool get _compact => widget.compact;

  /// [desktop] spacing, or the [phone] spacing measured off the phone mock.
  double _g(double desktop, double phone) => _compact ? phone : _gap(desktop);
  String _code = '';

  @override
  void initState() {
    super.initState();
    // The email hint follows the workspace: you@<workspace>.com. Editing it
    // also clears a "workspace not found" error.
    _workspace.addListener(() => setState(() => _workspaceError = null));
  }

  /// Time left before the outstanding code expires, floored at zero.
  Duration get _codeRemaining {
    final issued = _codeIssuedAt;
    if (issued == null) return Duration.zero;
    final left =
        DemoAuthBackend.codeLifetime - DateTime.now().difference(issued);
    return left.isNegative ? Duration.zero : left;
  }

  /// Starts (or restarts) the countdown for a freshly issued code.
  void _startCountdown() {
    _ticker?.cancel();
    setState(() => _codeIssuedAt = DateTime.now());
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _codeRemaining == Duration.zero) return t.cancel();
      setState(() {});
    });
  }

  Future<void> _resend() async {
    await context.read<AuthProvider>().resend();
    if (mounted) _startCountdown();
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
  void dispose() {
    _ticker?.cancel();
    _workspace.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _identify() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>()..clearError();
    final error = await auth.checkWorkspace(_workspace.text.trim());
    if (!mounted) return;
    if (error != null) {
      setState(() => _workspaceError = error);
      _formKey.currentState!.validate();
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _findWorkspace() async {
    final auth = context.read<AuthProvider>();
    String? found;
    final values = await showFormDialog(
      context,
      title: 'Find your workspace',
      subtitle: 'Enter the email address you sign in with.',
      submitLabel: 'Find',
      busyLabel: 'Searching...',
      fields: [
        FormFieldSpec(
          label: 'Work email',
          icon: Icons.mail_outline,
          email: true,
          initial: _email.text.trim(),
        ),
      ],
      onSubmit: (v) async {
        final (slug, error) = await auth.findWorkspace(v['Work email']!);
        found = slug;
        return error;
      },
    );
    if (values == null || found == null || !mounted) return;
    setState(() {
      _workspace.text = found!;
      if (_email.text.trim().isEmpty) _email.text = values['Work email']!;
    });
    showToast(context, 'Found your workspace: $found.');
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;
    // Success flips the provider to awaitingVerification, which is step 3.
    final auth = context.read<AuthProvider>();
    await auth.signIn(_email.text, _password.text);
    // A code was just issued: run its expiry countdown.
    if (mounted && auth.status == AuthStatus.awaitingVerification) {
      _startCountdown();
    }
  }

  Future<void> _verify() async {
    if (_code.length != OtpField.defaultLength) return;
    final auth = context.read<AuthProvider>();
    await auth.verify(_code);
    // Stop the countdown before the router tears this form down, so no timer
    // outlives the widget.
    if (auth.status == AuthStatus.authenticated) _ticker?.cancel();
    if (!mounted) return;
    // Failed: clear the boxes for another try. Success needs no navigation —
    // the AppRouter guard reacts to the auth change; this only marks the form
    // so the confirmation shows during that handoff.
    if (auth.status != AuthStatus.authenticated) {
      _otpKey.currentState?.clear();
      setState(() => _code = '');
    } else {
      setState(() => _succeeded = true);
    }
  }

  Future<void> _restart({bool clearEmail = false}) async {
    final auth = context.read<AuthProvider>();
    if (auth.status == AuthStatus.awaitingVerification) {
      await auth.cancelVerification();
    } else {
      auth.clearError();
    }
    _ticker?.cancel();
    _codeIssuedAt = null;
    _password.clear();
    if (clearEmail) _email.clear();
    setState(() {
      _step = 0;
      _code = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final busy = auth.busy;
    _tight = MediaQuery.sizeOf(context).height < 900;
    final step = auth.status == AuthStatus.awaitingVerification ? 2 : _step;

    const stepNames = ['IDENTIFY', 'PASSWORD', 'VERIFY'];
    final subtitleStyle = _compact
        ? const TextStyle(fontSize: 15, height: 1.45, color: OE.body)
        : const TextStyle(fontSize: 15.5, color: OE.body);
    final subtitle = switch (step) {
      0 => Text(
          'Enter your workspace and work email to continue.',
          style: subtitleStyle,
        ),
      1 => Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Signing in to '),
              TextSpan(
                text: _workspace.text.trim(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: OE.ink,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          style: subtitleStyle,
        ),
      _ => Text(
          'Enter the 6-digit code from your authenticator app.',
          style: subtitleStyle,
        ),
    };

    if (_succeeded) return const _SignedIn();

    // A locked account replaces the form: there is nothing useful to submit
    // until the lock lifts.
    final locked = auth.lockedUntil;
    if (locked != null) {
      return AccountLockedPanel(
        email: _email.text.trim(),
        lockedUntil: locked,
        onBack: () => _restart(),
        onReset: () => context.go(AppRoutes.forgotPassword),
      );
    }

    return Form(
      key: _formKey,
      // Keyed by step so each step assembles afresh, in reading order.
      child: Column(
        key: ValueKey(step),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: staggerIn([
          if (step > 0) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: _Back(onTap: busy ? null : _restart),
            ),
            SizedBox(height: _g(26, 18)),
          ],
          Text(
            'STEP ${step + 1} OF 3 · ${stepNames[step]}',
            style: OE.mono.copyWith(
              fontSize: _compact ? 10.5 : 12.5,
              letterSpacing: _compact ? 2 : 2.4,
              color: _compact ? OE.hint : OE.muted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            switch (step) {
              1 => 'Enter your password',
              2 => 'Two-factor verification',
              _ => 'Sign in',
            },
            style: TextStyle(
              fontSize: _compact ? 24 : 30,
              fontWeight: FontWeight.w600,
              letterSpacing: -.5,
              color: OE.ink,
            ),
          ),
          SizedBox(height: _compact ? 8 : 10),
          subtitle,
          ExpandFade(
            visible: auth.error != null,
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: AuthMessage(
                text: auth.error ?? '',
                detail: auth.errorDetail,
                isError: true,
              ),
            ),
          ),
          ExpandFade(
            visible: auth.notice != null,
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: AuthMessage(text: auth.notice ?? '', isError: false),
            ),
          ),
          SizedBox(height: _g(38, 26)),
          ...switch (step) {
            0 => _identifyStep(MediaQuery.sizeOf(context).width >= 600),
            1 => _passwordStep(busy, auth.error != null),
            _ => _verifyStep(auth),
          },
          // The phone mock has no rule above the footer, just space.
          if (_compact)
            const SizedBox(height: 22)
          else ...[
            SizedBox(height: _gap(32)),
            const Divider(height: 1, color: OE.border),
            SizedBox(height: _gap(24)),
          ],
          if (step == 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Protected by enterprise password policy · 5 attempts '
                'before lockout',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, height: 1.4, color: OE.muted),
              ),
            )
          else if (step == 2)
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                const Text(
                  'Having trouble? ',
                  style: TextStyle(fontSize: 14.5, color: OE.body),
                ),
                _Link(
                  'Contact support',
                  fontSize: 14.5,
                  onTap: busy ? null : _contactSupport,
                ),
              ],
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                Text(
                  'New to One Enterprise? ',
                  style: TextStyle(
                    fontSize: _compact ? 13.5 : 14.5,
                    color: OE.body,
                  ),
                ),
                _Link(
                  _compact ? 'Create an account' : 'Create New Account',
                  fontSize: _compact ? 13.5 : 14.5,
                  color: _compact ? _phoneLink : OE.link,
                  // Routing is centralized: this reports intent only.
                  onTap: busy ? null : () => context.go(AppRoutes.register),
                ),
              ],
            ),
        ]),
      ),
    );
  }

  /// The phone mock's links are a brighter blue than the desktop's navy.
  static const _phoneLink = Color(0xFF3E5FD9);

  List<Widget> _identifyStep(bool wide) => [
        _Field(
          compact: _compact,
          label: 'Workspace',
          controller: _workspace,
          hint: 'your-workspace',
          suffix: '.oneenterprise.io',
          validator: (v) => RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(v?.trim() ?? '')
              ? _workspaceError
              : 'Enter your workspace name',
          onSubmitted: _identify,
        ),
        const SizedBox(height: 8),
        Wrap(
          children: [
            const Text(
              "Don't know your workspace? ",
              style: TextStyle(fontSize: 13, color: OE.muted),
            ),
            _Link(
              'Find it here',
              fontSize: 13,
              color: _compact ? _phoneLink : OE.link,
              onTap: _findWorkspace,
            ),
          ],
        ),
        SizedBox(height: _g(22, 18)),
        _Field(
          compact: _compact,
          label: 'Work email',
          controller: _email,
          hint:
              'you@${_workspace.text.trim().isEmpty ? 'acmecorp' : _workspace.text.trim()}.com',
          keyboardType: TextInputType.emailAddress,
          validator: emailValidator,
          onSubmitted: _identify,
        ),
        SizedBox(height: _g(20, 18)),
        _PrimaryButton(
          'Continue',
          height: _compact ? 46 : 52,
          loading: context.watch<AuthProvider>().busy,
          onTap: context.watch<AuthProvider>().busy ? null : _identify,
        ),
        SizedBox(height: _g(26, 22)),
        Row(
          children: [
            if (wide) const SizedBox(width: 37),
            const Expanded(child: Divider(color: OE.border)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'or continue with',
                style: TextStyle(fontSize: 12.5, color: OE.hint),
              ),
            ),
            const Expanded(child: Divider(color: OE.border)),
            if (wide) const SizedBox(width: 37),
          ],
        ),
        SizedBox(height: _g(24, 20)),
        _SocialButton(
          'Google',
          Image.asset(
            'assets/google logo.png',
            width: 18,
            height: 18,
            errorBuilder: (_, __, ___) => const SizedBox(width: 18, height: 18),
          ),
          compact: _compact,
        ),
        SizedBox(height: _compact ? 9 : 10),
        _SocialButton(
          'Microsoft',
          const _MicrosoftMark(),
          compact: _compact,
        ),
        SizedBox(height: _compact ? 9 : 10),
        _SocialButton(
          _compact ? 'Company SSO' : 'Company SSO (SAML)',
          const Icon(Icons.people_outline, size: 20, color: OE.ink),
          compact: _compact,
        ),
      ];

  List<Widget> _passwordStep(bool busy, bool rejected) => [
        _AccountCard(
          email: _email.text.trim(),
          onSwitch: busy ? null : () => _restart(clearEmail: true),
        ),
        SizedBox(height: _gap(28)),
        _Field(
          label: 'Password',
          controller: _password,
          hint: 'Enter your password',
          obscure: true,
          hasError: rejected,
          validator: passwordValidator,
          onSubmitted: _authenticate,
        ),
        SizedBox(height: _gap(20)),
        Row(
          children: [
            SizedBox.square(
              dimension: 18,
              child: Checkbox(
                value: _rememberDevice,
                activeColor: OE.accent,
                side: const BorderSide(color: OE.hint),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
                onChanged: (v) => setState(() => _rememberDevice = v ?? false),
              ),
            ),
            const SizedBox(width: 12),
            // Short enough to sit beside "Forgot password?" on a phone
            // without truncating; the 30-day term is in the policy line below.
            const Expanded(
              child: Text(
                'Remember me',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14.5, color: OE.body),
              ),
            ),
            _Link(
              'Forgot password?',
              fontSize: 14.5,
              color: OE.accent,
              onTap: busy ? null : () => context.go(AppRoutes.forgotPassword),
            ),
          ],
        ),
        SizedBox(height: _gap(28)),
        _PrimaryButton(
          'Sign in',
          loading: busy,
          onTap: busy ? null : _authenticate,
        ),
      ];

  List<Widget> _verifyStep(AuthProvider auth) => [
        LoginOtpField(
          otpKey: _otpKey,
          enabled: !auth.busy,
          hasError: auth.error != null,
          demoCode: auth.demoCode,
          onChanged: (v) => setState(() => _code = v),
          onCompleted: (_) => _verify(),
        ),
        SizedBox(height: _gap(14)),
        _CodeStatus(
          remaining: _codeRemaining,
          onResend: auth.busy ? null : _resend,
        ),
        SizedBox(height: _gap(24)),
        _PrimaryButton(
          'Verify and sign in',
          loading: auth.busy,
          onTap: auth.busy || _code.length != OtpField.defaultLength
              ? null
              : _verify,
        ),
      ];
}

/// Label above a 50px outlined input, with an optional grey suffix block
/// (".oneenterprise.io") inside the border.
class _Field extends StatefulWidget {
  const _Field({
    this.compact = false,
    required this.label,
    required this.controller,
    required this.hint,
    this.suffix,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.onSubmitted,
    this.hasError = false,
  });

  final bool compact;
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final bool obscure;

  /// Outlines the field in red when the submit was rejected, even though the
  /// value itself passes local validation (a wrong password is well-formed).
  final bool hasError;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late bool _hidden = widget.obscure;

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c),
      );

  @override
  Widget build(BuildContext context) {
    Widget? suffix;
    if (widget.suffix != null) {
      // Sized to its text. An aligned Container would expand to the whole
      // width the decorator offers and squeeze the input itself to nothing.
      suffix = Container(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: widget.compact ? 12 : 15),
        decoration: const BoxDecoration(
          color: OE.fill,
          borderRadius: BorderRadius.horizontal(right: Radius.circular(7)),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            widget.suffix!,
            style: OE.mono.copyWith(
              fontSize: widget.compact ? 12 : 14,
              color: OE.muted,
            ),
          ),
        ),
      );
    } else if (widget.obscure) {
      suffix = IconButton(
        tooltip: _hidden ? 'Show password' : 'Hide password',
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 18,
          color: OE.muted,
        ),
        onPressed: () => setState(() => _hidden = !_hidden),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: widget.compact ? 13 : 14.5,
            fontWeight: FontWeight.w600,
            color: OE.ink,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          onFieldSubmitted: (_) => widget.onSubmitted?.call(),
          style: const TextStyle(fontSize: 16, color: OE.ink),
          cursorColor: OE.button,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(fontSize: 16, color: OE.hint),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 17,
              vertical: widget.compact ? 14 : 15,
            ),
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(minHeight: 48),
            filled: true,
            fillColor: Colors.white,
            border: _border(OE.border),
            enabledBorder: _border(widget.hasError ? OE.danger : OE.border),
            focusedBorder: _border(widget.hasError ? OE.danger : OE.button),
            errorBorder: _border(OE.danger),
            focusedErrorBorder: _border(OE.danger),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
    this.label, {
    required this.onTap,
    this.loading = false,
    this.height = 52,
  });

  final String label;
  final double height;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: OE.button,
          disabledBackgroundColor: OE.button.withValues(alpha: .55),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton(this.label, this.icon, {this.compact = false});

  final String label;
  final Widget icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact
          ? 44
          : MediaQuery.sizeOf(context).height < 900
              ? 42
              : 48,
      child: OutlinedButton(
        // No identity provider is configured for this workspace (the backend
        // has no OAuth/SAML integration), so say so rather than do nothing.
        onPressed: () => showToast(
          context,
          "$label sign-in isn't set up for this workspace. Continue with "
          'your work email.',
          isError: true,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: OE.ink,
          side: const BorderSide(color: OE.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w500,
                  color: OE.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Microsoft's four-square mark. The bundled asset carries the wordmark too,
/// which shrinks to an unreadable smudge at icon size.
class _MicrosoftMark extends StatelessWidget {
  const _MicrosoftMark();

  @override
  Widget build(BuildContext context) {
    Widget sq(int c) => Container(width: 8, height: 8, color: Color(c));
    return SizedBox.square(
      dimension: 17,
      child: Wrap(
        spacing: 1,
        runSpacing: 1,
        children: [
          sq(0xFFF25022),
          sq(0xFF7FBA00),
          sq(0xFF00A4EF),
          sq(0xFFFFB900),
        ],
      ),
    );
  }
}

/// Bold navy inline link ("Find it here", "Create New Account").
class _Link extends StatelessWidget {
  const _Link(
    this.text, {
    required this.fontSize,
    required this.onTap,
    this.color = OE.link,
  });

  final String text;
  final double fontSize;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chevron_left, size: 18, color: OE.muted),
            SizedBox(width: 6),
            Text('Back', style: TextStyle(fontSize: 15, color: OE.muted)),
          ],
        ),
      ),
    );
  }
}

/// The signed-in-as card on the password step; Switch returns to step 1.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.email, required this.onSwitch});

  final String email;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 15, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OE.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7CC5C0), Color(0xFF2C6E7F)],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: OE.ink),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Not you? Use a different account',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: OE.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _Link('Switch', fontSize: 14.5, color: OE.accent, onTap: onSwitch),
        ],
      ),
    );
  }
}

/// "Code expires in 04:57 · Resend" under the OTP boxes. Once the code has
/// expired the countdown is replaced by a plain prompt to request a new one.
class _CodeStatus extends StatelessWidget {
  const _CodeStatus({required this.remaining, required this.onResend});

  final Duration remaining;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final expired = remaining == Duration.zero;
    final mm = remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          expired ? 'Code expired · ' : 'Code expires in $mm:$ss · ',
          style: TextStyle(
            fontSize: 13.5,
            color: expired ? OE.ink : OE.muted,
          ),
        ),
        _Link('Resend', fontSize: 13.5, color: OE.accent, onTap: onResend),
      ],
    );
  }
}

/// Shown between the code being accepted and the router presenting the
/// dashboard, so a sign-in confirms rather than simply blanking.
class _SignedIn extends StatelessWidget {
  const _SignedIn();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopIn(
              child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFDCF5E6),
            ),
            child: const Icon(
              Icons.check,
              size: 28,
              color: Color(0xFF2E9E5B),
            ),
          )),
          const SizedBox(height: 26),
          FadeIn(
              delay: Motion.stagger * 3,
              child: const Text(
                "You're in",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.5,
                  color: OE.ink,
                ),
              )),
          const SizedBox(height: 10),
          FadeIn(
            delay: Motion.stagger * 5,
            child: const Text(
              'Redirecting to your dashboard...',
              style: TextStyle(fontSize: 15, color: OE.muted),
            ),
          ),
        ],
      ),
    );
  }
}
