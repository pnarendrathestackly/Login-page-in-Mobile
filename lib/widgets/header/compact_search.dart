import 'dart:async';

import 'package:flutter/material.dart';

import '../../main.dart';
import '../../widgets.dart';

/// Compact header search.
///
/// Wide: a small field, capped well below the header width so it never
/// dominates the bar or pushes the notification/profile controls off-screen.
/// Narrow: an icon that expands into a field on tap, and collapses when empty.
class CompactSearch extends StatefulWidget {
  const CompactSearch({super.key, this.maxWidth = 260, this.expandable = false});

  /// Upper bound on the field. It shrinks below this when the header is tight.
  final double maxWidth;

  /// Start as an icon-only button (tablet/mobile) rather than a field.
  final bool expandable;

  @override
  State<CompactSearch> createState() => _CompactSearchState();
}

class _CompactSearchState extends State<CompactSearch> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // Collapse an expandable search again once it loses focus while empty, so
    // it does not sit open taking room it is not using.
    if (!_focus.hasFocus && _controller.text.isEmpty && _open) {
      setState(() => _open = false);
    }
  }

  void _onChanged(String value) {
    // Debounced so typing does not fire a request per keystroke. The query is
    // held until the user pauses; there is no search endpoint yet, so this is
    // where that call will go.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || value.trim().isEmpty) return;
    });
  }

  void _submit(String q) {
    if (q.trim().isEmpty) return;
    showToast(
      context,
      'Search is not connected to a backend yet.',
      isError: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.expandable && !_open) {
      return IconButton(
        tooltip: 'Search',
        icon: const Icon(Icons.search, color: kInk),
        onPressed: () {
          setState(() => _open = true);
          // Focus after the field exists.
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _focus.requestFocus());
        },
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: SizedBox(
        height: 38,
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _submit,
          style: const TextStyle(fontSize: 13.5, color: kInk),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search',
            hintStyle: const TextStyle(fontSize: 13.5, color: kMuted),
            prefixIcon: const Icon(Icons.search, size: 18, color: kMuted),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 34, minHeight: 34),
            filled: true,
            fillColor: const Color(0xFFF7F7FC),
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
            border: _border(kBorder),
            enabledBorder: _border(kBorder),
            focusedBorder: _border(kIndigo, width: 1.5),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color c, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: c, width: width),
      );
}
