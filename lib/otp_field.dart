import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'motion.dart';

/// Six single-character boxes that behave like one field.
///
/// Handles auto-advance, backspace-to-previous, and paste of a full code into
/// any box. [onCompleted] fires once all six are filled.
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.hasError = false,
    this.length = defaultLength,
  });

  /// Digits in a code. Callers validating a code length read this rather than
  /// hardcoding 6 in each place.
  static const defaultLength = 6;

  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool hasError;
  final int length;

  @override
  State<OtpField> createState() => OtpFieldState();
}

class OtpFieldState extends State<OtpField> {
  late final List<TextEditingController> _controllers = List.generate(
    widget.length,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _nodes = List.generate(
    widget.length,
    (_) => FocusNode(),
  );

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _value => _controllers.map((c) => c.text).join();

  /// Lets the parent reset the boxes after a failed attempt.
  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    widget.onChanged('');
    if (mounted) _nodes.first.requestFocus();
  }

  void _spread(String digits, int from) {
    // A paste lands in one box; fan it out across the boxes from there.
    // Start at 0 when the whole code arrives, so pasting into any box works.
    final start = digits.length >= widget.length ? 0 : from;
    for (var i = start; i < widget.length; i++) {
      final index = i - start;
      if (index < digits.length) _controllers[i].text = digits[index];
    }
    final landing = (start + digits.length).clamp(0, widget.length - 1);
    _nodes[landing].requestFocus();
    _emit();
  }

  void _emit() {
    final value = _value;
    widget.onChanged(value);
    if (value.length == widget.length && !value.contains(' ')) {
      _nodes[widget.length - 1].unfocus();
      widget.onCompleted?.call(value);
    }
  }

  void _onChanged(String raw, int i) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      _spread(digits, i);
      return;
    }
    _controllers[i].text = digits;
    if (digits.isNotEmpty && i < widget.length - 1) {
      _nodes[i + 1].requestFocus();
    }
    _emit();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, int i) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[i].text.isEmpty &&
        i > 0) {
      _controllers[i - 1].clear();
      _nodes[i - 1].requestFocus();
      _emit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Sized from the space actually available rather than a screen-width
    // breakpoint, so the boxes fit inside the login card at 320px as well as
    // in a wide split layout.
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth < 320 ? 6.0 : 8.0;
        final available = constraints.maxWidth - gap * (widget.length - 1);
        final box = (available / widget.length).clamp(34.0, 56.0);
        return Semantics(
          label: '${widget.length}-digit verification code',
          textField: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < widget.length; i++)
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == widget.length - 1 ? 0 : gap,
                    ),
                    child: _box(i, box),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _box(int i, double size) {
    final border = widget.hasError ? kDanger : kBorder;
    final filled = _controllers[i].text.isNotEmpty;
    return Focus(
      onKeyEvent: (node, event) => _onKey(node, event, i),
      child: AnimatedScale(
        // A filled box nudges up very slightly, so entry has visible rhythm.
        scale: Motion.reduced(context) || !filled ? 1.0 : 1.04,
        duration: Motion.duration(context, Motion.micro),
        curve: Motion.standardCurve,
        child: SizedBox(
          height: size,
          child: TextField(
            controller: _controllers[i],
            focusNode: _nodes[i],
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            textAlign: TextAlign.center,
            // No maxLength: it would truncate a pasted code to one digit before
            // _onChanged could spread it across the boxes.
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              // Track the box so a digit never clips in a narrow card.
              fontSize: size < 44 ? 18 : 22,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: kFieldFill,
              contentPadding: EdgeInsets.zero,
              enabledBorder: _outline(border),
              border: _outline(border),
              focusedBorder: _outline(widget.hasError ? border : kIndigo),
            ),
            onChanged: (v) => _onChanged(v, i),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _outline(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c),
      );
}
