import 'dart:async';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/platform/modules.dart';
import '../../dashboard.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';
import '../../widgets.dart';

/// Every destination the signed-in user may open, as (title, path).
List<({String title, String path})> _destinations(BuildContext context) {
  final perms = context.read<AuthProvider>().permissions;
  return [
    for (final s in DashboardSection.values)
      (title: s.label, path: pathForSection(s)),
    for (final m in visibleModules(perms))
      for (final p in visiblePages(m, perms))
        (title: '${m.title} › ${p.title}', path: m.pathFor(p)),
  ];
}

/// Compact header search.
///
/// Wide: a small field, capped well below the header width so it never
/// dominates the bar or pushes the notification/profile controls off-screen.
/// Narrow: an icon that expands into a field on tap, and collapses when empty.
class CompactSearch extends StatefulWidget {
  const CompactSearch({
    super.key,
    this.maxWidth = 260,
    this.expandable = false,
    this.hint = 'Search',
    this.shortcut,
  });

  final String hint;

  /// Keyboard hint badge at the end of the field, e.g. `⌘K`.
  final String? shortcut;

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

  /// Searches the pages and module screens the user can open (there is no
  /// search service for records yet). One match opens it; several are
  /// offered in a list.
  // ponytail: navigation search only. Point this at a search API when one
  // exists to cover tenants, users and audit logs as the hint promises.
  Future<void> _submit(String q) async {
    final words = q.trim().toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (words.isEmpty) return;
    final matches = [
      for (final d in _destinations(context))
        if (words.every(d.title.toLowerCase().contains)) d,
    ];
    if (matches.isEmpty) {
      showToast(context, 'No matching results found.', isError: true);
      return;
    }
    final pick = matches.length == 1
        ? matches.single
        : await showDialog<({String title, String path})>(
            context: context,
            builder: (context) => SimpleDialog(
              title: Text('Results for "${q.trim()}"'),
              children: [
                for (final m in matches.take(12))
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, m),
                    child: Text(m.title),
                  ),
              ],
            ),
          );
    if (pick == null || !mounted) return;
    _controller.clear();
    _focus.unfocus();
    context.go(pick.path);
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
        height: 40,
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _submit,
          style: const TextStyle(fontSize: 13.5, color: kInk),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            hintStyle: const TextStyle(fontSize: 14, color: kMuted),
            suffixIcon: widget.shortcut == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Center(
                      widthFactor: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: kBorder),
                        ),
                        child: Text(
                          widget.shortcut!,
                          style: const TextStyle(fontSize: 10.5, color: kMuted),
                        ),
                      ),
                    ),
                  ),
            prefixIcon: const Icon(Icons.search, size: 18, color: kMuted),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 42, minHeight: 34),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
            border: _border(kBorder),
            enabledBorder: _border(kBorder),
            focusedBorder: _border(kIndigo, width: 1.5),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color c, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: c, width: width),
      );
}
