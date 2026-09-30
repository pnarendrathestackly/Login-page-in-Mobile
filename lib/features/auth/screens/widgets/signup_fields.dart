import 'package:flutter/material.dart';

import '../login/login_screen.dart' show OE;

/// Styling for the inline agreement links on the terms step. Not tappable:
/// the legal documents have no route yet.
const kAgreementLink = TextStyle(
  fontWeight: FontWeight.w600,
  color: OE.accent,
);

/// Label above an outlined dropdown, matching the sign-up page's text fields.
class SignupDropdown extends StatelessWidget {
  const SignupDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
    this.labelOf,
  });

  final String label;
  final String? value;
  final String hint;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  /// Maps a stored value to what is shown, e.g. a country code to its name.
  final String Function(String)? labelOf;

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
              TextSpan(text: label),
              const TextSpan(
                text: ' *',
                style: TextStyle(color: OE.danger),
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
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 15, color: OE.hint),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: OE.muted),
          style: const TextStyle(fontSize: 15, color: OE.ink),
          validator: (v) => v == null ? '$label is required' : null,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: OE.accent, width: 1.4),
            ),
          ),
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o,
                child: Text(
                  labelOf?.call(o) ?? o,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The logo drop zone. Picking is real; the bytes are not stored — the demo
/// backend has nowhere to put them.
class LogoPicker extends StatelessWidget {
  const LogoPicker({
    super.key,
    required this.fileName,
    required this.onPick,
    required this.onClear,
  });

  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            const Text(
              'Organization Logo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: OE.ink,
              ),
            ),
            Text(
              'OPTIONAL',
              style: OE.mono.copyWith(fontSize: 10.5, color: OE.hint),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFC),
              border: Border.all(color: OE.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(
                  fileName == null
                      ? Icons.file_upload_outlined
                      : Icons.check_circle_outline,
                  size: 22,
                  color: fileName == null ? OE.muted : const Color(0xFF2E9E5B),
                ),
                const SizedBox(height: 10),
                if (fileName == null)
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Upload logo', style: kAgreementLink),
                        TextSpan(
                          text: ' — PNG, JPG up to 5MB',
                          style: TextStyle(color: OE.muted),
                        ),
                      ],
                    ),
                    style: TextStyle(fontSize: 13.5),
                  )
                else ...[
                  Text(
                    fileName!,
                    style: const TextStyle(fontSize: 13.5, color: OE.ink),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: onClear,
                    child: const Text(
                      'Remove',
                      style: TextStyle(fontSize: 12.5, color: OE.muted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One checkbox row on the terms step.
class ConsentRow extends StatelessWidget {
  const ConsentRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.body,
    this.optional = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final InlineSpan body;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 18,
              child: Checkbox(
                value: value,
                activeColor: OE.navy,
                side: const BorderSide(color: OE.hint),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    body,
                    if (optional)
                      TextSpan(
                        text: '  OPTIONAL',
                        style: OE.mono.copyWith(
                          fontSize: 10.5,
                          color: OE.hint,
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
    );
  }
}
