import 'package:flutter/material.dart';

import '../../main.dart';
import '../../widgets.dart';

/// Shared modals: record detail, add/edit forms, and destructive confirmation.
///
/// Reuses the app's existing `AuthField`, `PrimaryButton` and `showToast` so
/// forms here look and validate like the login and sign-up forms.

/// Read-only detail sheet — the "View" action on every directory row.
Future<void> showDetailDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Map<String, String> fields,
  Widget? leading,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _Shell(
      title: title,
      subtitle: subtitle,
      leading: leading,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, entry) in fields.entries.indexed) ...[
            if (i > 0) const Divider(color: kBorder, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 13, color: kMuted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: kMuted),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// One field in a [showFormDialog].
class FormFieldSpec {
  const FormFieldSpec({
    required this.label,
    required this.icon,
    this.initial = '',
    this.required = true,
    this.email = false,
    this.keyboardType,
  });

  final String label;
  final IconData icon;
  final String initial;
  final bool required;

  /// Validates the address shape as well as presence.
  final bool email;
  final TextInputType? keyboardType;
}

/// Add/edit form. Returns the entered values, or null if cancelled.
///
/// Validation runs on submit and blocks the save — the same contract the login
/// and sign-up forms use.
Future<Map<String, String>?> showFormDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<FormFieldSpec> fields,
  String submitLabel = 'Save',
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _FormDialog(
      title: title,
      subtitle: subtitle,
      fields: fields,
      submitLabel: submitLabel,
    ),
  );
}

class _FormDialog extends StatefulWidget {
  const _FormDialog({
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.submitLabel,
  });

  final String title;
  final String subtitle;
  final List<FormFieldSpec> fields;
  final String submitLabel;

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers = [
    for (final f in widget.fields) TextEditingController(text: f.initial),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      for (final (i, f) in widget.fields.indexed)
        f.label: _controllers[i].text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Shell(
      title: widget.title,
      subtitle: widget.subtitle,
      body: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, f) in widget.fields.indexed) ...[
              if (i > 0) const SizedBox(height: 14),
              AuthField(
                hint: f.label,
                icon: f.icon,
                controller: _controllers[i],
                keyboardType: f.keyboardType,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) {
                    return f.required ? '${f.label} is required.' : null;
                  }
                  if (f.email && !RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$')
                      .hasMatch(value)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: kMuted),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: PrimaryButton(label: widget.submitLabel, onTap: _submit),
        ),
      ],
    );
  }
}

/// Confirmation for anything destructive. Nothing deletes or deactivates
/// without passing through here first.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _Shell(
      title: title,
      subtitle: message,
      body: const SizedBox.shrink(),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: kMuted),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor:
                destructive ? const Color(0xFFDC2626) : kIndigo,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shared dialog chrome, so every modal has the same padding, radius and
/// border as the app's cards.
class _Shell extends StatelessWidget {
  const _Shell({
    required this.title,
    required this.subtitle,
    required this.body,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: kInk,
                            ),
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: kMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              body,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
