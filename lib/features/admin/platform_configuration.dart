part of 'super_admin_dashboard.dart';

/// The saved platform configuration.
typedef PlatformConfig = ({
  String name,
  String url,
  String timeZone,
  String language,
  Map<String, Map<String, String>> integrations,
});

// ponytail: held in memory for the session — there is no config API yet.
// Survives navigation between pages, resets on restart.
final platformConfig = ValueNotifier<PlatformConfig>((
  name: 'Java Enterprise Suite',
  url: 'https://app.javasuite.enterprise',
  timeZone: 'UTC +05:30 (India Standard Time)',
  language: 'ENGLISH',
  integrations: const {},
));

const _timeZones = [
  'UTC -08:00 (Pacific Time)',
  'UTC -05:00 (Eastern Time)',
  'UTC +00:00 (Greenwich Mean Time)',
  'UTC +01:00 (Central European Time)',
  'UTC +04:00 (Gulf Standard Time)',
  'UTC +05:30 (India Standard Time)',
  'UTC +08:00 (Singapore Time)',
  'UTC +09:00 (Japan Standard Time)',
];

const _languages = ['ENGLISH', 'HINDI', 'FRENCH', 'GERMAN', 'SPANISH'];

const _blue = Color(0xFF2563EB);

String? _validatePort(String v) {
  final n = int.tryParse(v);
  return n == null || n < 1 || n > 65535
      ? 'Enter a port from 1 to 65535.'
      : null;
}

/// Each integration and the fields its Configure dialog asks for.
const _integrationSpecs = [
  (
    title: 'SMTP Configuration',
    sub: 'Manage email server settings',
    fields: [
      FormFieldSpec(label: 'SMTP host', icon: Icons.dns_outlined),
      FormFieldSpec(
        label: 'Port',
        icon: Icons.numbers,
        keyboardType: TextInputType.number,
        validator: _validatePort,
      ),
      FormFieldSpec(
        label: 'Sender email',
        icon: Icons.alternate_email,
        email: true,
      ),
    ],
  ),
  (
    title: 'SMS Gateway',
    sub: 'Twilio integration settings',
    fields: [
      FormFieldSpec(label: 'Account SID', icon: Icons.badge_outlined),
      FormFieldSpec(
        label: 'Sender number',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
      ),
    ],
  ),
  (
    title: 'API Gateway',
    sub: 'External system access tokens',
    fields: [
      FormFieldSpec(label: 'Gateway base URL', icon: Icons.link),
      FormFieldSpec(label: 'Token name', icon: Icons.key_outlined),
    ],
  ),
];

/// Platform Configuration (`/admin/settings`): identity, regional defaults,
/// integrations. Edits are a draft until Save Changes; Cancel restores the
/// last saved values.
class PlatformConfigScreen extends StatefulWidget implements OwnsPageHeading {
  const PlatformConfigScreen({super.key});

  @override
  State<PlatformConfigScreen> createState() => _PlatformConfigScreenState();
}

class _PlatformConfigScreenState extends State<PlatformConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _url = TextEditingController();
  late String _timeZone;
  late String _language;
  late Map<String, Map<String, String>> _integrations;
  bool _saved = false;

  /// Bumped on Cancel so the dropdowns rebuild from the restored values —
  /// a form field reads its initial value only once.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final c = platformConfig.value;
    _name.text = c.name;
    _url.text = c.url;
    _timeZone = c.timeZone;
    _language = c.language;
    _integrations = {...c.integrations};
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  /// Any edit hides the stale "saved" banner.
  void _edited() {
    if (_saved) setState(() => _saved = false);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    platformConfig.value = (
      name: _name.text.trim(),
      url: _url.text.trim(),
      timeZone: _timeZone,
      language: _language,
      integrations: {..._integrations},
    );
    setState(() => _saved = true);
  }

  void _cancel() {
    _formKey.currentState!.reset();
    setState(() {
      _load();
      _saved = false;
      _generation++;
    });
  }

  Future<void> _configure(
    ({String title, String sub, List<FormFieldSpec> fields}) spec,
  ) async {
    final current = _integrations[spec.title] ?? const {};
    final result = await showFormDialog(
      context,
      title: spec.title,
      subtitle: spec.sub,
      submitLabel: 'Apply',
      fields: [
        for (final f in spec.fields)
          FormFieldSpec(
            label: f.label,
            icon: f.icon,
            initial: current[f.label] ?? '',
            email: f.email,
            keyboardType: f.keyboardType,
            validator: f.validator,
          ),
      ],
    );
    if (result == null || !mounted) return;
    setState(() {
      _integrations[spec.title] = result;
      _saved = false;
    });
    showToast(context, '${spec.title} updated. Save changes to apply it.');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final left = Column(
          children: [
            _basic(),
            const SizedBox(height: 18),
            _regional(box.maxWidth >= 560),
          ],
        );
        final right = _SecurityPanel(fill: wide);

        return Form(
          key: _formKey,
          onChanged: _edited,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Text(
                    'Administration',
                    style: TextStyle(fontSize: 15, color: _ink),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.chevron_right, size: 16, color: _ink),
                  ),
                  Flexible(
                    child: Text(
                      'Platform Configuration',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: _ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Platform Configuration',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage core platform identity, regional defaults, and '
                'security handling.',
                style: TextStyle(fontSize: 13, color: _ink),
              ),
              if (_saved) ...[
                const SizedBox(height: 22),
                const _SavedBanner(),
              ],
              const SizedBox(height: 18),
              if (wide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 61, child: left),
                      const SizedBox(width: 18),
                      Expanded(flex: 39, child: right),
                    ],
                  ),
                )
              else ...[
                left,
                const SizedBox(height: 18),
                right,
              ],
              const SizedBox(height: 18),
              _integrationsCard(),
              const SizedBox(height: 18),
              const _DeploymentNote(),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _PlainButton(label: 'Cancel', onTap: _cancel),
                    _Button(
                      label: 'Save Changes',
                      icon: Icons.save_outlined,
                      primary: true,
                      height: 52,
                      onTap: _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _basic() {
    return _Section(
      icon: Icons.settings_applications_outlined,
      title: 'Basic Configuration',
      divider: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('PLATFORM NAME'),
          _ConfigField(
            controller: _name,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Enter the platform name' : null,
          ),
          const SizedBox(height: 22),
          const _FieldLabel('PLATFORM URL'),
          _ConfigField(
            controller: _url,
            keyboardType: TextInputType.url,
            validator: (v) {
              final u = Uri.tryParse((v ?? '').trim());
              return u != null && u.scheme == 'https' && u.host.isNotEmpty
                  ? null
                  : 'Enter an https:// address';
            },
          ),
        ],
      ),
    );
  }

  Widget _regional(bool twoUp) {
    final zone = _ConfigDropdown(
      key: ValueKey('zone$_generation'),
      value: _timeZone,
      items: _timeZones,
      onChanged: (v) => setState(() => _timeZone = v),
    );
    final lang = _ConfigDropdown(
      key: ValueKey('lang$_generation'),
      value: _language,
      items: _languages,
      filled: true,
      onChanged: (v) => setState(() => _language = v),
    );
    return _Section(
      icon: Icons.language,
      title: 'Regional Configuration',
      child: twoUp
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _labelled('DEFAULT TIME ZONE', zone)),
                const SizedBox(width: 24),
                Expanded(child: _labelled('DEFAULT LANGUAGE', lang)),
              ],
            )
          : Column(
              children: [
                _labelled('DEFAULT TIME ZONE', zone),
                const SizedBox(height: 18),
                _labelled('DEFAULT LANGUAGE', lang),
              ],
            ),
    );
  }

  Widget _labelled(String label, Widget field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_FieldLabel(label), field],
      );

  Widget _integrationsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(26, 18, 26, 16),
            child: Row(
              children: [
                Icon(Icons.hub_outlined, size: 24, color: _blue),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Communication & Integration',
                    style: TextStyle(fontSize: 20, color: _ink),
                  ),
                ),
              ],
            ),
          ),
          for (final spec in _integrationSpecs) ...[
            const Divider(height: 1, color: _line),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 18, 26, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                spec.title,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  color: _ink,
                                ),
                              ),
                            ),
                            if (_integrations.containsKey(spec.title)) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check_circle,
                                size: 15,
                                color: _green,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          spec.sub,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    width: 102,
                    child: OutlinedButton(
                      onPressed: () => _configure(spec),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: _blue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Configure',
                        style: TextStyle(fontSize: 13.5, color: _blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Marker for screens that draw their own breadcrumb and title, so the shell
/// does not add a second heading above them.
abstract interface class OwnsPageHeading {}

class _SavedBanner extends StatelessWidget {
  const _SavedBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCFE8D8)),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF15803D),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 18),
            const Icon(Icons.check_circle, size: 22, color: Color(0xFF15803D)),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                'Your changes has been saved successfully.',
                style: _mono.copyWith(
                  fontSize: 17,
                  color: const Color(0xFF15803D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.divider = false,
  });

  final IconData icon;
  final String title;
  final Widget child;

  /// A rule under the title (Basic has one, Regional does not).
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, divider ? 14 : 20),
            child: Row(
              children: [
                Icon(icon, size: 22, color: _blue),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (divider) const Divider(height: 1, color: _line),
          Padding(
            padding: EdgeInsets.fromLTRB(22, divider ? 20 : 12, 22, 22),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: .8,
          color: _body,
        ),
      ),
    );
  }
}

OutlineInputBorder _configBorder(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: c),
    );

class _ConfigField extends StatelessWidget {
  const _ConfigField({
    required this.controller,
    required this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 17, color: _ink),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF5F6F8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: _configBorder(_line),
        enabledBorder: _configBorder(_line),
        focusedBorder: _configBorder(_blue),
      ),
    );
  }
}

class _ConfigDropdown extends StatelessWidget {
  const _ConfigDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.filled = false,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  /// Grey fill (Language) rather than white (Time zone), as in the design.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.expand_more, color: _ink),
      style: const TextStyle(fontSize: 17, color: _ink),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: filled ? const Color(0xFFF5F6F8) : Colors.white,
        contentPadding: EdgeInsets.fromLTRB(filled ? 28 : 14, 11, 12, 11),
        border: _configBorder(_line),
        enabledBorder: _configBorder(_line),
        focusedBorder: _configBorder(_blue),
      ),
      items: [
        for (final i in items)
          DropdownMenuItem(
            value: i,
            child: Text(i, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _SecurityPanel extends StatelessWidget {
  const _SecurityPanel({required this.fill});

  /// Stretching to the height of the column beside it: pins System Health to
  /// the bottom. Off when stacked, where there is no height to fill.
  final bool fill;

  static const _points = [
    (
      icon: Icons.verified_user_outlined,
      title: 'Configuration version control',
      sub: 'All changes are tracked and can be rolled back.',
    ),
    (
      icon: Icons.enhanced_encryption_outlined,
      title: 'Encryption of sensitive credentials',
      sub: 'API keys and passwords are AES-256 encrypted.',
    ),
    (
      icon: Icons.manage_search,
      title: 'Audit logs',
      sub: 'Comprehensive logging of administrative actions.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFEEF2F7),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: const Row(
              children: [
                Icon(Icons.shield, size: 22, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Security Handling',
                    style: TextStyle(fontSize: 20, color: _ink),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 40, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in _points) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(p.icon, size: 19, color: _blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title,
                              style: const TextStyle(
                                fontSize: 15,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.sub,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _body,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (p != _points.last) const SizedBox(height: 26),
                ],
              ],
            ),
          ),
          if (fill) const Spacer(),
          Container(
            color: const Color(0xFFF1F3F6),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.health_and_safety_outlined,
                    size: 22,
                    color: _blue,
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Health',
                      style: TextStyle(fontSize: 15, color: _ink),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Optimal State',
                      style: TextStyle(fontSize: 15, color: Color(0xFF22A55A)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeploymentNote extends StatelessWidget {
  const _DeploymentNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 22, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAEE),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 22, color: _blue),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deployment Note',
                  style: TextStyle(fontSize: 15, color: _ink),
                ),
                SizedBox(height: 14),
                Text(
                  'Changes to Core Platform configurations may require a '
                  'service restart for integrated modules to reflect the '
                  'updates completely.',
                  style: TextStyle(fontSize: 15, color: _body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White bordered text button (Cancel).
class _PlainButton extends StatelessWidget {
  const _PlainButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
      ),
    );
  }
}
