import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.obscure = false,
    this.validator,
    this.crossValidator,
    this.options,
  });

  final String label;
  final IconData icon;
  final String initial;
  final bool required;

  /// Validates the address shape as well as presence.
  final bool email;
  final TextInputType? keyboardType;

  /// Masked input with a show/hide toggle; the value is not trimmed.
  final bool obscure;

  /// Extra rule run after the required/email checks, on the trimmed value.
  /// Returns the message to show, or null when valid.
  final String? Function(String value)? validator;

  /// Rule that depends on other fields (an end date after its start date),
  /// run after [validator] passes. [form] maps every field's label to its
  /// current trimmed value.
  final String? Function(String value, Map<String, String> form)?
      crossValidator;

  /// When set, the field is a dropdown of these choices instead of free text.
  final List<String>? options;
}

/// Add/edit form. Returns the entered values, or null if cancelled.
///
/// Validation runs on submit and blocks the save — the same contract the login
/// and sign-up forms use.
///
/// With [onSubmit], the dialog runs the save itself: the button shows
/// [busyLabel] and cannot be pressed twice, a failure (a non-null message)
/// is shown inside the dialog with the input kept, and the dialog closes only
/// once the save succeeds.
Future<Map<String, String>?> showFormDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<FormFieldSpec> fields,
  String submitLabel = 'Save',
  String busyLabel = 'Saving...',
  Future<String?> Function(Map<String, String> values)? onSubmit,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _FormDialog(
      title: title,
      subtitle: subtitle,
      fields: fields,
      submitLabel: submitLabel,
      busyLabel: busyLabel,
      onSubmit: onSubmit,
    ),
  );
}

class _FormDialog extends StatefulWidget {
  const _FormDialog({
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.submitLabel,
    required this.busyLabel,
    this.onSubmit,
  });

  final String title;
  final String subtitle;
  final List<FormFieldSpec> fields;
  final String submitLabel;
  final String busyLabel;
  final Future<String?> Function(Map<String, String> values)? onSubmit;

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

  bool _busy = false;
  String? _error;

  /// Set by the first submit: from then on every field re-checks as it
  /// changes, so each message clears the moment its field is fixed.
  bool _submitted = false;

  Map<String, String> get _form => {
        for (final (i, f) in widget.fields.indexed)
          f.label: _controllers[i].text.trim(),
      };

  Future<void> _submit() async {
    if (_busy) return;
    // Errors show under each field that failed; there is no form-wide banner
    // for them, since it would repeat the same thing for every mistake.
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() {
        _submitted = true;
        _error = null;
      });
      return;
    }
    final values = {
      for (final (i, f) in widget.fields.indexed)
        f.label: f.obscure ? _controllers[i].text : _controllers[i].text.trim(),
    };
    final save = widget.onSubmit;
    if (save == null) {
      Navigator.of(context).pop(values);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      error = await save(values);
    } catch (_) {
      error = 'Something went wrong. Please try again.';
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(values);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  String? _validate(FormFieldSpec f, String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) {
      if (!f.required) return null;
      // "Due (YYYY-MM-DD)" reads as "Due date"; the format hint is for input.
      var name = f.label.replaceAll(RegExp(r'\s*\(.*\)'), '');
      if (f.label.contains('YYYY-MM-DD')) name = '$name date';
      if (f.label.contains('HH:MM')) name = '$name time';
      return f.options != null
          ? 'Select a ${name.toLowerCase()}.'
          : '$name is required.';
    }
    if (f.email && !RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(value)) {
      return 'Enter a valid email address.';
    }
    return f.validator?.call(value) ?? f.crossValidator?.call(value, _form);
  }

  /// Blocks keystrokes that can never be valid for the field's rule, so a
  /// date or number field cannot take letters in the first place.
  static List<TextInputFormatter>? _formatters(FormFieldSpec f) {
    if (f.validator == validateIsoDate) {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        LengthLimitingTextInputFormatter(10),
      ];
    }
    if (f.validator == validateTime) {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
        LengthLimitingTextInputFormatter(5),
      ];
    }
    if (f.keyboardType == TextInputType.number) {
      return [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _Shell(
      title: widget.title,
      subtitle: widget.subtitle,
      body: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.always
            : AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              AuthMessage(text: _error!, isError: true),
              const SizedBox(height: 14),
            ],
            for (final (i, f) in widget.fields.indexed) ...[
              if (i > 0) const SizedBox(height: 14),
              if (f.options != null)
                DropdownButtonFormField<String>(
                  initialValue: f.options!.contains(_controllers[i].text)
                      ? _controllers[i].text
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: f.label,
                    prefixIcon: Icon(f.icon, size: 18, color: kMutedStrong),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    for (final o in f.options!)
                      DropdownMenuItem(value: o, child: Text(o)),
                  ],
                  validator: (v) => _validate(f, v),
                  onChanged:
                      _busy ? null : (v) => _controllers[i].text = v ?? '',
                )
              else
                AuthField(
                  hint: f.label,
                  icon: f.icon,
                  controller: _controllers[i],
                  keyboardType: f.keyboardType,
                  inputFormatters: _formatters(f),
                  obscure: f.obscure,
                  validator: (v) => _validate(f, v),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          // Nothing is saved on Cancel; blocked mid-save so a request that
          // is already running cannot be orphaned.
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: kMuted),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: PrimaryButton(
            label: widget.submitLabel,
            loading: _busy,
            loadingLabel: widget.busyLabel,
            onTap: _submit,
          ),
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
            backgroundColor: destructive ? kDanger : kIndigo,
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
      backgroundColor: kSurfaceElevated,
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
                // Wraps rather than a Row: a long submit label beside Cancel
                // overflows a phone-width dialog.
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Shared field rules for [FormFieldSpec.validator]. Top-level functions so
// they can sit in `const` field lists. Each receives the trimmed, non-empty
// value and returns the message to show, or null when valid. Messages say
// what is wrong with this field specifically, never a generic "invalid".

/// Whole number in [min]..[max]; [what] names the field in the message.
String? _wholeNumber(String v, String what, {int min = 1, required int max}) {
  final n = int.tryParse(v);
  if (n == null) {
    return v.contains('.')
        ? '$what must be a whole number, without decimals.'
        : '$what must be a number, using digits only.';
  }
  if (n < min) return '$what must be at least $min.';
  if (n > max) return '$what cannot be more than $max.';
  return null;
}

String? validatePositiveInt(String v) =>
    _wholeNumber(v, 'This value', max: 100000);

/// Course length in hours.
String? validateDurationHours(String v) =>
    _wholeNumber(v, 'Duration', max: 500);

/// Open positions on a job.
String? validateOpenings(String v) => _wholeNumber(v, 'Openings', max: 500);

/// A money amount; separators such as "1,20,000" are allowed.
String? validatePositiveAmount(String v) {
  if (!RegExp(r'^[0-9,]+$').hasMatch(v)) {
    return v.contains('.')
        ? 'Amount must be a whole number, without decimals.'
        : 'Amount must use digits only (commas are allowed).';
  }
  final n = int.tryParse(v.replaceAll(',', ''));
  if (n == null || n <= 0) return 'Amount must be greater than 0.';
  if (n > 1000000000) return 'Amount cannot be more than 1,000,000,000.';
  return null;
}

String? validatePercent(String v) =>
    _wholeNumber(v, 'Progress', min: 0, max: 100);

/// A whole-number rating from 1 to 5.
String? validateRating(String v) {
  if (int.tryParse(v) == null && double.tryParse(v) != null) {
    return 'Rating must be a whole number from 1 to 5.';
  }
  return _wholeNumber(v, 'Rating', max: 5);
}

/// A rating from 1 to 5; one decimal place such as 3.5 is allowed.
String? validateDecimalRating(String v) {
  final n = double.tryParse(v);
  if (n == null) return 'Rating must be a number, such as 4 or 3.5.';
  if (n < 1 || n > 5) return 'Rating must be between 1 and 5.';
  if (!RegExp(r'^\d(\.\d)?$').hasMatch(v)) {
    return 'Rating can have at most one decimal place, such as 3.5.';
  }
  return null;
}

/// Parses a strict YYYY-MM-DD calendar date, or null. Unlike
/// `DateTime.tryParse`, it rejects dates that do not exist: 2026-02-30 would
/// otherwise silently roll over to 2 March.
DateTime? parseIsoDate(String v) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final date = DateTime(y, mo, d);
  return date.year == y && date.month == mo && date.day == d ? date : null;
}

String? validateIsoDate(String v) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
    return 'Enter the date as YYYY-MM-DD, for example 2026-10-15.';
  }
  final month = int.parse(v.substring(5, 7));
  if (month < 1 || month > 12) return 'Month must be from 01 to 12.';
  if (parseIsoDate(v) == null) return '$v is not a real calendar date.';
  final year = int.parse(v.substring(0, 4));
  if (year < 2000 || year > 2100) return 'Year must be between 2000 and 2100.';
  return null;
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// A deadline: today or later, at most two years out.
String? validateDueDate(String v, Map<String, String> _) {
  final d = parseIsoDate(v)!;
  if (d.isBefore(_today())) return 'Due date cannot be in the past.';
  if (d.isAfter(_today().add(const Duration(days: 730)))) {
    return 'Due date must be within the next two years.';
  }
  return null;
}

/// Leave start: may be backdated (sick leave), but within a year either way.
String? validateLeaveStart(String v, Map<String, String> _) {
  final d = parseIsoDate(v)!;
  if (d.isBefore(_today().subtract(const Duration(days: 365)))) {
    return 'Start date cannot be more than a year in the past.';
  }
  if (d.isAfter(_today().add(const Duration(days: 365)))) {
    return 'Start date must be within the next year.';
  }
  return null;
}

/// Leave end: on or after the start, and no more than 180 days of leave.
String? validateLeaveEnd(String v, Map<String, String> form) {
  final end = parseIsoDate(v)!;
  final start = parseIsoDate(form['From (YYYY-MM-DD)'] ?? '');
  // No start yet (or an invalid one): that field shows its own error.
  if (start == null) return null;
  if (end.isBefore(start)) return 'End date cannot be before the start date.';
  if (end.difference(start).inDays + 1 > 180) {
    return 'Leave cannot be longer than 180 days in one request.';
  }
  return null;
}

String? validateTime(String v) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v);
  if (m == null) return 'Enter the time as HH:MM, for example 09:30.';
  if (int.parse(m[1]!) > 23) return 'Hour must be from 00 to 23.';
  if (int.parse(m[2]!) > 59) return 'Minutes must be from 00 to 59.';
  return null;
}

/// Check-out must come after check-in on the same day.
String? validateCheckOut(String v, Map<String, String> form) {
  final ci = form['Check-in (HH:MM)'] ?? '';
  if (ci.isEmpty || validateTime(ci) != null) return null;
  int minutes(String t) =>
      int.parse(t.split(':')[0]) * 60 + int.parse(t.split(':')[1]);
  return minutes(v) <= minutes(ci)
      ? 'Check-out must be later than check-in ($ci).'
      : null;
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// A pay period written as "Month YYYY", such as "April 2026".
String? validatePayPeriod(String v) {
  final m = RegExp(r'^([A-Za-z]+)\s+(\d{4})$').firstMatch(v);
  if (m == null) return 'Enter the period as month and year, e.g. April 2026.';
  if (!_months.any((x) => x.toLowerCase() == m[1]!.toLowerCase())) {
    return '"${m[1]}" is not a month. Spell it in full, e.g. April.';
  }
  final y = int.parse(m[2]!);
  if (y < 2000 || y > 2100) return 'Year must be between 2000 and 2100.';
  return null;
}
