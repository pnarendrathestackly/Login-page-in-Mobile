import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import 'auth.dart';
import 'core/platform/regions.dart';
import 'features/auth/screens/widgets/auth_status_panel.dart';
import 'features/auth/screens/widgets/signup_fields.dart';
import 'features/auth/screens/login/login_screen.dart' show OE;
import 'features/auth/screens/login/widgets/brand_header.dart';
import 'router/app_router.dart';
import 'widgets.dart';

/// Three-step sign-up: the organization, the admin account that will own it,
/// then a review before the account is created.
///
/// Only the account step talks to the backend — steps 1 and 3 are local, so a
/// half-finished wizard never leaves a partial account behind.
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, required this.controller});

  final AuthController controller;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  /// One key per step: validating step 2 must not fail on step 1's fields,
  /// which are no longer in the tree.
  final _keys = [GlobalKey<FormState>(), GlobalKey<FormState>()];

  final _org = TextEditingController();
  final _workspace = TextEditingController();
  final _stateText = TextEditingController();
  final _city = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _orgType;
  String? _industry;
  String? _companySize;
  String? _country;
  String? _state;
  String? _timeZone;

  /// Chosen logo, kept in memory only — see [_pickLogo].
  String? _logoName;

  int _step = 0;

  /// Set once the account exists: the wizard is replaced by the welcome
  /// screen.
  bool _created = false;

  /// The three required consents, plus the optional mailing opt-in.
  bool _agreedTerms = false;
  bool _agreedAuthority = false;
  bool _agreedDpa = false;
  bool _wantsUpdates = true;

  bool get _consented => _agreedTerms && _agreedAuthority && _agreedDpa;

  List<TextEditingController> get _all => [
        _org,
        _workspace,
        _stateText,
        _city,
        _first,
        _last,
        _email,
        _mobile,
        _username,
        _password,
        _confirm,
      ];

  bool _workspaceEdited = false;

  @override
  void initState() {
    super.initState();
    // The suggested username follows the name until the user edits it.
    _first.addListener(_suggestUsername);
    _last.addListener(_suggestUsername);
    _org.addListener(_suggestWorkspace);
  }

  /// "ABC Technologies Pvt Ltd" -> "ABC-TECH": the first two words, upper
  /// case, each clipped to four characters so the slug stays short. Stops once
  /// the user edits the field by hand.
  void _suggestWorkspace() {
    if (_workspaceEdited) return;
    final words = _org.text
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase())
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.length <= 4 ? w : w.substring(0, 4));
    final suggestion = words.join('-');
    if (_workspace.text != suggestion) _workspace.text = suggestion;
  }

  bool _usernameEdited = false;

  void _suggestUsername() {
    if (_usernameEdited) return;
    final first = _first.text.trim().toLowerCase();
    final last = _last.text.trim().toLowerCase();
    final suggestion = [first, last].where((p) => p.isNotEmpty).join('.');
    if (_username.text != suggestion) _username.text = suggestion;
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  static const _logoTypes = ['png', 'jpg', 'jpeg'];
  static const _maxLogoBytes = 5 * 1024 * 1024;

  Future<void> _pickLogo() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: _logoTypes,
      );
    } catch (_) {
      if (mounted) {
        showToast(context, 'Unable to open the file picker.', isError: true);
      }
      return;
    }
    if (file == null || !mounted) return; // cancelled
    final ext = (file.extension ?? '').toLowerCase().replaceAll('.', '');
    if (!_logoTypes.contains(ext)) {
      showToast(context, 'Unsupported file format. Use a PNG or JPG image.',
          isError: true);
      return;
    }
    if ((await file.length() ?? 0) > _maxLogoBytes) {
      if (mounted) {
        showToast(context, 'File size exceeds the 5MB limit.', isError: true);
      }
      return;
    }
    // ponytail: the name only — the demo backend has nowhere to store bytes.
    if (mounted) setState(() => _logoName = file!.name);
  }

  void _next() {
    if (!_keys[_step].currentState!.validate()) return;
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      context.go(AppRoutes.login);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _submit() async {
    if (!_consented) {
      showToast(
        context,
        'Please accept the three required agreements to continue',
        isError: true,
      );
      return;
    }
    final error = await widget.controller.register(
      name: '${_first.text.trim()} ${_last.text.trim()}',
      email: _email.text,
      password: _password.text,
      organization: _org.text,
      workspace: _workspace.text,
      mobile: _mobile.text,
      username: _username.text,
    );
    if (!mounted) return;
    if (error != null) {
      // The clash is with a field on step 2, so go back to it.
      setState(() => _step = 1);
      showToast(context, error, isError: true);
      return;
    }
    // The welcome screen replaces the wizard rather than bouncing straight to
    // sign-in: the workspace address is shown once, and is worth reading.
    setState(() => _created = true);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds so the Continue button reflects controller.busy.
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    final form = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 532),
            child: _body(context),
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
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 532),
                      child: _body(context),
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

  Widget _body(BuildContext context) {
    if (_created) return _welcome();
    const names = [
      'ORGANIZATION DETAILS',
      'SUPER ADMIN ACCOUNT',
      'TERMS & AUTHORIZATION',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _BackLink(onTap: widget.controller.busy ? null : _back),
        ),
        const SizedBox(height: 22),
        _Progress(step: _step),
        const SizedBox(height: 22),
        Text(
          'STEP ${_step + 1} OF 3 · ${names[_step]}',
          style: OE.mono.copyWith(
            fontSize: 11.5,
            letterSpacing: 2.2,
            color: OE.muted,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          switch (_step) {
            0 => 'Tell us about your organization',
            1 => 'Create your admin account',
            _ => 'Review and confirm',
          },
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
            color: OE.ink,
          ),
        ),
        const SizedBox(height: 8),
        _subtitle(),
        const SizedBox(height: 24),
        switch (_step) {
          0 => _organizationStep(),
          1 => _accountStep(),
          _ => _reviewStep(),
        },
        const SizedBox(height: 26),
        _PrimaryButton(
          label: _step == 2 ? 'Create account' : 'Continue',
          loading: widget.controller.busy,
          onTap: widget.controller.busy ? null : (_step == 2 ? _submit : _next),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            const Text(
              'Already have an organization? ',
              style: TextStyle(fontSize: 14.5, color: OE.body),
            ),
            _TextLink(
              'Sign in',
              onTap: widget.controller.busy
                  ? null
                  : () => context.go(AppRoutes.login),
            ),
          ],
        ),
      ],
    );
  }

  Widget _subtitle() {
    const style = TextStyle(fontSize: 15, height: 1.45, color: OE.body);
    if (_step == 1) {
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            const TextSpan(text: "You'll use this account to manage "),
            TextSpan(
              text: _org.text.trim().isEmpty
                  ? 'your organization'
                  : _org.text.trim(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: OE.ink,
              ),
            ),
            const TextSpan(text: '.'),
          ],
        ),
      );
    }
    return Text(
      _step == 0
          ? "This creates your organization's workspace on One Enterprise."
          : 'One last step before we create '
              '${_org.text.trim().isEmpty ? 'your organization' : _org.text.trim()}'
              "'s workspace.",
      style: style,
    );
  }

  /// Shown after the account is created, with the new workspace address.
  Widget _welcome() {
    final org = _org.text.trim();
    final slug = _workspace.text.trim().toLowerCase();
    return AuthStatusPanel(
      icon: Icons.check,
      tint: const Color(0xFFDCF5E6),
      iconColor: const Color(0xFF2E9E5B),
      title: 'Welcome to One Enterprise',
      body: TextSpan(
        children: [
          TextSpan(
            text: org,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: OE.ink,
            ),
          ),
          const TextSpan(
            text: ' is ready. Your Super Admin account has been created — '
                'verify your email to activate full access.',
          ),
        ],
      ),
      callout: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.mail_outline, size: 18, color: OE.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: "We've sent a verification link to your official "
                          'email. Your workspace:  ',
                    ),
                    TextSpan(
                      text: '$slug.oneenterprise.io',
                      style: OE.mono.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OE.ink,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: OE.body,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        AuthPrimaryButton(
          label: 'Go to sign in',
          onTap: () => context.go(AppRoutes.login),
        ),
      ],
      footer: Wrap(
        alignment: WrapAlignment.center,
        children: [
          const Text(
            "Didn't get the email? ",
            style: TextStyle(fontSize: 13.5, color: OE.muted),
          ),
          _TextLink(
            'Resend verification',
            fontSize: 13.5,
            onTap: () => showToast(context, 'Verification email sent again.'),
          ),
        ],
      ),
    );
  }

  Widget _organizationStep() => Form(
        key: _keys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Field(
              label: 'Organization Name',
              controller: _org,
              hint: 'ABC Technologies Pvt Ltd',
              validator: (v) => (v ?? '').trim().length < 2
                  ? 'Enter your organization name'
                  : null,
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'Workspace',
              controller: _workspace,
              hint: 'ABC-TECH',
              onChanged: (_) => _workspaceEdited = true,
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Workspace is required';
                if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]*$').hasMatch(value)) {
                  return 'Use letters, numbers and dashes only';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _workspaceEdited
                      ? 'Signs in at '
                          '${_workspace.text.trim().toLowerCase()}'
                          '.oneenterprise.io'
                      : 'Auto-generated from your name — ',
                  style: const TextStyle(fontSize: 12.5, color: OE.muted),
                ),
                if (!_workspaceEdited)
                  _TextLink(
                    'edit manually',
                    fontSize: 12.5,
                    onTap: () => setState(() => _workspaceEdited = true),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SignupDropdown(
              label: 'Organization Type',
              value: _orgType,
              hint: 'Select a type',
              options: organizationTypes,
              onChanged: (v) => setState(() => _orgType = v),
            ),
            const SizedBox(height: 18),
            SignupDropdown(
              label: 'Industry',
              value: _industry,
              hint: 'Select an industry',
              options: industries,
              onChanged: (v) => setState(() => _industry = v),
            ),
            const SizedBox(height: 18),
            SignupDropdown(
              label: 'Company Size',
              value: _companySize,
              hint: 'Select a size',
              options: companySizes,
              onChanged: (v) => setState(() => _companySize = v),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, box) {
                final country = SignupDropdown(
                  label: 'Country',
                  value: _country,
                  hint: 'Select',
                  options: countries.keys.toList(),
                  labelOf: (code) => countries[code]!,
                  // The state list is per country, so a change clears it.
                  onChanged: (v) => setState(() {
                    _country = v;
                    _state = null;
                  }),
                );
                final state = statesOf(_country).isEmpty
                    ? _Field(
                        label: 'State',
                        controller: _stateText,
                        hint: 'State or region',
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      )
                    : SignupDropdown(
                        label: 'State',
                        value: _state,
                        hint: 'Select',
                        options: statesOf(_country),
                        onChanged: (v) => setState(() => _state = v),
                      );
                return box.maxWidth < 380
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [country, const SizedBox(height: 18), state],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: country),
                          const SizedBox(width: 16),
                          Expanded(child: state),
                        ],
                      );
              },
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'City',
              controller: _city,
              hint: 'Hyderabad',
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'City is required' : null,
            ),
            const SizedBox(height: 18),
            SignupDropdown(
              label: 'Time Zone',
              value: _timeZone,
              hint: 'Select a time zone',
              options: timeZones,
              onChanged: (v) => setState(() => _timeZone = v),
            ),
            const SizedBox(height: 18),
            LogoPicker(
              fileName: _logoName,
              onPick: _pickLogo,
              onClear: () => setState(() => _logoName = null),
            ),
          ],
        ),
      );

  Widget _accountStep() => Form(
        key: _keys[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _RoleNotice(),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, box) {
                final first = _Field(
                  label: 'First Name',
                  controller: _first,
                  hint: 'Ananya',
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                );
                final last = _Field(
                  label: 'Last Name',
                  controller: _last,
                  hint: 'Rao',
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                );
                // Side by side when there is room, stacked on a small phone.
                return box.maxWidth < 380
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [first, const SizedBox(height: 18), last],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: first),
                          const SizedBox(width: 16),
                          Expanded(child: last),
                        ],
                      );
              },
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'Official Email',
              controller: _email,
              hint: 'ananya.rao@abctech.com',
              keyboardType: TextInputType.emailAddress,
              validator: emailValidator,
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'Mobile Number',
              controller: _mobile,
              hint: '+91 98765 43210',
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
              ],
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.isEmpty) return 'Mobile number is required';
                if (digits.length < 7) return 'Enter a valid mobile number';
                return null;
              },
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'Username',
              controller: _username,
              hint: 'ananya.rao',
              onChanged: (_) => _usernameEdited = true,
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Username is required';
                if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(value)) {
                  return 'Use lowercase letters, numbers, dot, dash or underscore';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'Password',
              controller: _password,
              hint: 'Create a password',
              obscure: true,
              helper: 'Minimum 8 characters, with a number and a symbol.',
              validator: (v) {
                final base = passwordValidator(v);
                if (base != null) return base;
                final value = v ?? '';
                if (!RegExp(r'[0-9]').hasMatch(value)) {
                  return 'Include at least one number';
                }
                if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
                  return 'Include at least one symbol';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _Field(
              label: 'Confirm Password',
              controller: _confirm,
              hint: 'Re-enter password',
              obscure: true,
              validator: (v) =>
                  v == _password.text ? null : 'Passwords do not match',
            ),
          ],
        ),
      );

  Widget _reviewStep() {
    final org = _org.text.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        border: Border.all(color: OE.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          ConsentRow(
            value: _agreedTerms,
            onChanged: (v) => setState(() => _agreedTerms = v),
            body: const TextSpan(
              children: [
                TextSpan(text: 'I have read and agree to the '),
                TextSpan(text: 'Terms of Service', style: kAgreementLink),
                TextSpan(text: ' and '),
                TextSpan(text: 'Privacy Policy', style: kAgreementLink),
                TextSpan(text: '.'),
              ],
            ),
          ),
          ConsentRow(
            value: _agreedAuthority,
            onChanged: (v) => setState(() => _agreedAuthority = v),
            body: TextSpan(
              children: [
                const TextSpan(text: 'I confirm I am authorized to register '),
                TextSpan(
                  text: org.isEmpty ? 'this organization' : org,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: OE.ink,
                  ),
                ),
                const TextSpan(
                  text: ' and accept responsibility as its Super '
                      'Administrator.',
                ),
              ],
            ),
          ),
          ConsentRow(
            value: _agreedDpa,
            onChanged: (v) => setState(() => _agreedDpa = v),
            body: const TextSpan(
              children: [
                TextSpan(text: 'I agree to the '),
                TextSpan(text: 'Data Processing Agreement', style: kAgreementLink),
                TextSpan(
                  text: ' governing how organization data is stored and '
                      'processed.',
                ),
              ],
            ),
          ),
          ConsentRow(
            value: _wantsUpdates,
            onChanged: (v) => setState(() => _wantsUpdates = v),
            optional: true,
            body: const TextSpan(
              text: 'Send me product updates and security notices',
            ),
          ),
        ],
      ),
    );
  }
}

/// Three segments, filled up to and including the current step.
class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${step + 1} of 3',
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step ? OE.navy : OE.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The blue panel explaining that this account owns the workspace.
class _RoleNotice extends StatelessWidget {
  const _RoleNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        border: Border.all(color: const Color(0xFFD6DEFF)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 18, color: OE.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: OE.body,
                ),
                children: [
                  const TextSpan(text: 'This account is automatically '),
                  const TextSpan(text: 'assigned the '),
                  TextSpan(
                    text: 'SUPER_ADMIN',
                    style: OE.mono.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OE.ink,
                    ),
                  ),
                  const TextSpan(
                    text: ' role with full access to your workspace.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label (with a red asterisk when required) above a 50px outlined input.
class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.helper,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final String? helper;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderSide: BorderSide(color: OE.border),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: widget.label),
              const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFFDC2626)),
                ),
            ],
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: OE.ink,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          validator: widget.validator,
          onChanged: widget.onChanged,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(fontSize: 15, color: OE.ink),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(fontSize: 15, color: OE.hint),
            helperText: widget.helper,
            helperMaxLines: 2,
            helperStyle: const TextStyle(fontSize: 12.5, color: OE.muted),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: border,
            enabledBorder: border,
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: OE.accent, width: 1.4),
            ),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 19,
                      color: OE.muted,
                    ),
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chevron_left, size: 20, color: OE.muted),
            SizedBox(width: 2),
            Text('Back', style: TextStyle(fontSize: 15, color: OE.muted)),
          ],
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink(this.label, {required this.onTap, this.fontSize = 14.5});

  final String label;
  final VoidCallback? onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: OE.accent,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: OE.button,
          disabledBackgroundColor: OE.button.withValues(alpha: .55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
