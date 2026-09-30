part of 'super_admin_dashboard.dart';

/// An uploaded image: its file name and bytes.
typedef BrandImage = ({String name, Uint8List bytes});

/// The saved platform branding.
typedef Branding = ({
  String platformName,
  String companyName,
  String tagline,
  String footer,
  String copyright,
  String welcome,
  bool dark,
  String primary,
  String secondary,
  String accent,
  BrandImage? logo,
  BrandImage? favicon,
  BrandImage? emailLogo,
  BrandImage? background,
});

// ponytail: held in memory for the session, like platformConfig — uploads
// are kept as bytes, not sent anywhere. Swap for an API + object storage.
final platformBranding = ValueNotifier<Branding>((
  platformName: 'Java Enterprise Suite',
  companyName: 'Oracle Corporation',
  tagline: 'Empowering Enterprise Intelligence',
  footer: 'System Maintained by IT Dept.',
  copyright: '© 2024 platform branding. All rights reserved.',
  welcome:
      'Welcome to Java Enterprise Suite.\nPlease authenticate to continue.',
  dark: false,
  primary: '#1976D2',
  secondary: '#FFFFFF',
  accent: '#4CAF50',
  logo: null,
  favicon: null,
  emailLogo: null,
  background: null,
));

const _mb = 1024 * 1024;

/// `#RRGGBB` → colour, or null when it is not a valid hex value.
Color? _hex(String s) {
  final m = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(s.trim());
  return m == null ? null : Color(int.parse('FF${m[1]}', radix: 16));
}

/// Platform Branding (`/admin/branding`): identity, logos, theme colours and
/// the login screen. A draft until Save Changes; Cancel restores.
class PlatformBrandingScreen extends StatefulWidget implements OwnsPageHeading {
  const PlatformBrandingScreen({super.key});

  @override
  State<PlatformBrandingScreen> createState() => _PlatformBrandingState();
}

class _PlatformBrandingState extends State<PlatformBrandingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _c = {
    for (final k in [
      'platformName',
      'companyName',
      'tagline',
      'footer',
      'copyright',
      'welcome',
      'primary',
      'secondary',
      'accent',
    ])
      k: TextEditingController(),
  };
  late bool _dark;
  BrandImage? _logo, _favicon, _emailLogo, _background;

  @override
  void initState() {
    super.initState();
    _load();
    // Swatches and counters follow the text as it is typed.
    for (final c in _c.values) {
      c.addListener(() => setState(() {}));
    }
  }

  void _load() {
    final b = platformBranding.value;
    _c['platformName']!.text = b.platformName;
    _c['companyName']!.text = b.companyName;
    _c['tagline']!.text = b.tagline;
    _c['footer']!.text = b.footer;
    _c['copyright']!.text = b.copyright;
    _c['welcome']!.text = b.welcome;
    _c['primary']!.text = b.primary;
    _c['secondary']!.text = b.secondary;
    _c['accent']!.text = b.accent;
    _dark = b.dark;
    _logo = b.logo;
    _favicon = b.favicon;
    _emailLogo = b.emailLogo;
    _background = b.background;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _t(String k) => _c[k]!.text.trim();

  Branding get _draft => (
        platformName: _t('platformName'),
        companyName: _t('companyName'),
        tagline: _t('tagline'),
        footer: _t('footer'),
        copyright: _t('copyright'),
        welcome: _c['welcome']!.text.trim(),
        dark: _dark,
        primary: _t('primary').toUpperCase(),
        secondary: _t('secondary').toUpperCase(),
        accent: _t('accent').toUpperCase(),
        logo: _logo,
        favicon: _favicon,
        emailLogo: _emailLogo,
        background: _background,
      );

  void _save() {
    if (!_formKey.currentState!.validate()) {
      showToast(context, 'Fix the highlighted fields first.', isError: true);
      return;
    }
    platformBranding.value = _draft;
    showToast(context, 'Branding saved.');
  }

  void _cancel() {
    _formKey.currentState!.reset();
    setState(_load);
  }

  /// Opens the system file picker; rejects the wrong type or an oversize file
  /// with a toast rather than storing it.
  Future<BrandImage?> _pick(List<String> types, int maxBytes) async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: types,
      );
    } catch (_) {
      if (mounted) {
        showToast(context, "Couldn't open the file picker.", isError: true);
      }
      return null;
    }
    if (file == null || !mounted) return null;
    final ext = (file.extension ?? '').toLowerCase().replaceAll('.', '');
    if (!types.contains(ext)) {
      showToast(context, 'Use a ${types.join(', ').toUpperCase()} file.',
          isError: true);
      return null;
    }
    final size = await file.length() ?? 0;
    if (!mounted) return null;
    if (size > maxBytes) {
      showToast(context, 'That file is over ${maxBytes ~/ _mb}MB.',
          isError: true);
      return null;
    }
    return (name: file.name, bytes: await file.readAsBytes());
  }

  String? _required(String? v, String what) =>
      (v ?? '').trim().isEmpty ? 'Enter the $what' : null;

  String? _color(String? v) =>
      _hex(v ?? '') == null ? 'Use a hex value like #1976D2' : null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1000;
        final twoUp = box.maxWidth >= 560;
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _identity(twoUp),
            const SizedBox(height: 20),
            _assets(twoUp),
            const SizedBox(height: 20),
            _theme(twoUp),
          ],
        );
        final right = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _loginBackground(),
            const SizedBox(height: 20),
            const _RulesCard(),
          ],
        );

        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 66, child: left),
                    const SizedBox(width: 24),
                    Expanded(flex: 34, child: right),
                  ],
                )
              else ...[
                left,
                const SizedBox(height: 20),
                right,
              ],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _PlainButton(label: 'Cancel', onTap: _cancel),
                    _OutlineBlueButton(
                      label: 'Preview',
                      onTap: () => _showPreview(context, _draft),
                    ),
                    _Button(
                      label: 'Save Changes',
                      icon: Icons.save_outlined,
                      primary: true,
                      height: 58,
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

  Widget _two(bool twoUp, Widget a, Widget b) => twoUp
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 20),
            Expanded(child: b),
          ],
        )
      : Column(children: [a, const SizedBox(height: 16), b]);

  Widget _identity(bool twoUp) {
    return _BrandCard(
      title: 'Platform Identity',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF1F4),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Basic Info',
          style: TextStyle(fontSize: 13, color: _body),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrandField(
            label: 'Platform Name',
            controller: _c['platformName']!,
            maxLength: 100,
            validator: (v) => _required(v, 'platform name'),
          ),
          const SizedBox(height: 18),
          _two(
            twoUp,
            _BrandField(
              label: 'Company Name',
              controller: _c['companyName']!,
              maxLength: 100,
              validator: (v) => _required(v, 'company name'),
            ),
            _BrandField(
              label: 'Tagline',
              controller: _c['tagline']!,
              maxLength: 100,
            ),
          ),
        ],
      ),
    );
  }

  Widget _assets(bool twoUp) {
    final logo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.image_outlined, size: 17, color: _body),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Company Logo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: .5,
                  color: _ink,
                ),
              ),
            ),
            Text(
              'PNG, SVG up to 5MB.',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DropZone(
          height: 192,
          onTap: () async {
            final f = await _pick(const ['png', 'svg'], 5 * _mb);
            if (f != null) setState(() => _logo = f);
          },
          child: _logo == null
              ? const _EmptyLogo()
              : _ImagePreview(_logo!, fit: BoxFit.contain),
        ),
      ],
    );

    final smallAssets = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AssetLabel('Favicon'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _DropZone(
              width: 76,
              height: 76,
              onTap: _pickFavicon,
              child: _favicon == null
                  ? const Icon(Icons.north_east, size: 12, color: _blue)
                  : _ImagePreview(_favicon!, fit: BoxFit.contain),
            ),
            _SmallButton('Upload Favicon', _pickFavicon),
          ],
        ),
        const SizedBox(height: 28),
        const _AssetLabel('Email Header Logo'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DropZone(
                height: 62,
                onTap: _pickEmailLogo,
                child: Text(
                  _emailLogo?.name ?? 'No file chosen',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, color: _body),
                ),
              ),
            ),
            const SizedBox(width: 20),
            _SmallButton('Upload File', _pickEmailLogo),
          ],
        ),
      ],
    );

    return _BrandCard(
      title: 'Visual Assets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _two(twoUp, logo, smallAssets),
          const SizedBox(height: 26),
          _two(
            twoUp,
            _BrandField(
              label: 'Footer Text',
              controller: _c['footer']!,
              maxLength: 200,
              lines: 2,
              counter: true,
            ),
            _BrandField(
              label: 'Copyright Text',
              controller: _c['copyright']!,
              maxLength: 100,
              lines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFavicon() async {
    final f = await _pick(const ['png', 'svg', 'ico'], 5 * _mb);
    if (f != null) setState(() => _favicon = f);
  }

  Future<void> _pickEmailLogo() async {
    final f = await _pick(const ['png', 'jpg', 'jpeg', 'svg'], 5 * _mb);
    if (f != null) setState(() => _emailLogo = f);
  }

  Widget _theme(bool twoUp) {
    Widget color(String label, String key) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: _ink,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _line),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _hex(_c[key]!.text) ?? Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: TextFormField(
                    controller: _c[key],
                    validator: _color,
                    style: _mono.copyWith(fontSize: 15, color: _body),
                    decoration: _brandDecoration(),
                  ),
                ),
              ],
            ),
          ],
        );

    final colors = [
      color('Primary Color', 'primary'),
      color('Secondary Color', 'secondary'),
      color('Accent Color', 'accent'),
    ];

    return _BrandCard(
      title: 'Theme Configuration',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Theme', style: TextStyle(fontSize: 17, color: _ink)),
              const SizedBox(width: 30),
              Flexible(
                child: _ThemeToggle(
                  dark: _dark,
                  onChanged: (v) => setState(() => _dark = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (twoUp)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < colors.length; i++) ...[
                  if (i > 0) const SizedBox(width: 30),
                  Expanded(child: colors[i]),
                ],
              ],
            )
          else
            for (final c in colors)
              Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
        ],
      ),
    );
  }

  Widget _loginBackground() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Login Background',
                    style: TextStyle(fontSize: 21, color: _ink),
                  ),
                ),
                _PanelLink('Change Image', () async {
                  final f = await _pick(const ['png', 'jpg', 'jpeg'], 10 * _mb);
                  if (f != null) setState(() => _background = f);
                }),
              ],
            ),
          ),
          SizedBox(
            height: 372,
            child: _LoginPreview(background: _background),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: _BrandField(
              label: 'Welcome Message',
              controller: _c['welcome']!,
              maxLength: 250,
              lines: 3,
              counter: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a mock of the login card using the draft branding.
void _showPreview(BuildContext context, Branding b) {
  final primary = _hex(b.primary) ?? const Color(0xFF1976D2);
  final accent = _hex(b.accent) ?? const Color(0xFF4CAF50);
  final bg = b.dark ? const Color(0xFF111827) : Colors.white;
  final fg = b.dark ? Colors.white : _ink;
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 480),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _LoginPreview(background: b.background)),
            Expanded(
              child: Container(
                color: bg,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (b.logo != null)
                      SizedBox(height: 40, child: _ImagePreview(b.logo!)),
                    const SizedBox(height: 12),
                    Text(
                      b.platformName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    Text(b.tagline, style: TextStyle(color: accent)),
                    const SizedBox(height: 16),
                    Text(b.welcome, style: TextStyle(color: fg)),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(backgroundColor: primary),
                      child: const Text('Sign in'),
                    ),
                    const Spacer(),
                    Text(
                      '${b.footer}  ·  ${b.copyright}',
                      style: TextStyle(
                          fontSize: 11, color: fg.withValues(alpha: .6)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

InputDecoration _brandDecoration() => InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      border: _configBorder(_line),
      enabledBorder: _configBorder(_line),
      focusedBorder: _configBorder(_blue),
    );

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFF7F8FA),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 21, color: _ink),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

class _BrandField extends StatelessWidget {
  const _BrandField({
    required this.label,
    required this.controller,
    required this.maxLength,
    this.validator,
    this.lines = 1,
    this.counter = false,
  });

  final String label;
  final TextEditingController controller;
  final int maxLength;
  final String? Function(String?)? validator;
  final int lines;

  /// "29/200" in the bottom-right corner of the box.
  final bool counter;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      validator: validator,
      maxLength: maxLength,
      minLines: lines,
      maxLines: lines,
      style: const TextStyle(fontSize: 17, color: _ink),
      decoration: _brandDecoration().copyWith(
        contentPadding: EdgeInsets.fromLTRB(15, 16, 15, counter ? 24 : 16),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: _ink,
          ),
        ),
        const SizedBox(height: 10),
        if (!counter)
          field
        else
          Stack(
            children: [
              field,
              Positioned(
                right: 12,
                bottom: 8,
                child: Text(
                  '${controller.text.length}/$maxLength',
                  style: const TextStyle(fontSize: 10.5, color: _muted),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _AssetLabel extends StatelessWidget {
  const _AssetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: .5,
          color: _ink,
        ),
      );
}

/// Dashed, tappable upload target.
class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.child,
    required this.onTap,
    this.width,
    this.height,
  });

  final Widget child;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: CustomPaint(
            painter: const _DashedBorder(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(6),
      ));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => false;
}

/// Uploaded image, or its name when it cannot be drawn (SVG, ICO).
class _ImagePreview extends StatelessWidget {
  const _ImagePreview(this.image, {this.fit = BoxFit.contain});

  final BrandImage image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // ponytail: Flutter has no built-in SVG renderer; show the file name
    // rather than add flutter_svg for a preview.
    final raster =
        RegExp(r'\.(png|jpe?g)$', caseSensitive: false).hasMatch(image.name);
    if (!raster) {
      return Text(
        image.name,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, color: _body),
      );
    }
    return Image.memory(
      image.bytes,
      fit: fit,
      errorBuilder: (_, __, ___) => Text(image.name),
    );
  }
}

class _EmptyLogo extends StatelessWidget {
  const _EmptyLogo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_upload_outlined, size: 30, color: _muted),
        SizedBox(height: 8),
        Text(
          'Click to upload your logo',
          style: TextStyle(fontSize: 13.5, color: _body),
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
      ),
    );
  }
}

class _OutlineBlueButton extends StatelessWidget {
  const _OutlineBlueButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: const BorderSide(color: _brand, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _brand,
          ),
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.dark, required this.onChanged});

  final bool dark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(bool value, IconData icon, String label) {
      final on = dark == value;
      return Flexible(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Semantics(
            button: true,
            selected: on,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: on ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: on
                    ? const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: on ? _ink : _body),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: on ? FontWeight.w500 : FontWeight.w400,
                        color: on ? _ink : _body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(false, Icons.light_mode_outlined, 'Light mode'),
          option(true, Icons.dark_mode_outlined, 'Dark mode'),
        ],
      ),
    );
  }
}

/// The login backdrop: the uploaded image, or a blue abstract default, with a
/// wireframe of the sign-in card on top.
class _LoginPreview extends StatelessWidget {
  const _LoginPreview({required this.background});

  final BrandImage? background;

  @override
  Widget build(BuildContext context) {
    Widget bar(double h, Color c, {double w = double.infinity}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
          ),
        );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (background != null)
          Image.memory(background!.bytes, fit: BoxFit.cover)
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B2A5B),
                  Color(0xFF5FA8D3),
                  Color(0xFF1C4E8A),
                  Color(0xFF0A1E44),
                ],
                stops: [0, .45, .7, 1],
              ),
            ),
          ),
        Center(
          child: FractionallySizedBox(
            widthFactor: .52,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(18, const Color(0xFFE5E7EB), w: 78),
                  const SizedBox(height: 16),
                  bar(28, const Color(0xFFE5E7EB)),
                  const SizedBox(height: 14),
                  bar(28, const Color(0xFFE5E7EB)),
                  const SizedBox(height: 14),
                  bar(38, const Color(0xFF151A45)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  static const _validation = [
    'Images: PNG, JPG, SVG max 5MB. Background max 10MB.',
    'Text fields max 100 chars; Messages max 250 chars.',
    'Colors must be valid hex values.',
  ];

  @override
  Widget build(BuildContext context) {
    const grey = Color(0xFF4B5563);
    const heading = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: .8,
      color: _ink,
    );

    Widget item(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 17, color: grey),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 15, color: grey),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.policy_outlined, size: 22, color: Color(0xFF374151)),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Security & Rules',
                  style: TextStyle(fontSize: 22, color: Color(0xFF374151)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('VALIDATION RULES', style: heading),
          const SizedBox(height: 10),
          for (final v in _validation) item(Icons.check_circle_outline, v),
          const Divider(height: 26, color: Color(0xFFD5DAE1)),
          const SizedBox(height: 8),
          const Text('SECURITY HANDLING', style: heading),
          const SizedBox(height: 10),
          item(Icons.admin_panel_settings_outlined,
              'Super Admin (RBAC) access only.'),
          item(Icons.history, 'All changes logged to Audit Trail.'),
        ],
      ),
    );
  }
}
