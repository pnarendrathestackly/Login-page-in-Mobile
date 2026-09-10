import 'package:flutter/material.dart';

import '../../auth.dart';
import '../../main.dart';

/// Shared by the header, the sidebar and the profile menu so all three run the
/// same handler.
class SignOutButton extends StatefulWidget {
  const SignOutButton({
    super.key,
    required this.controller,
    this.compact = false,
    this.iconOnly = false,
  });

  final AuthController controller;
  final bool compact;
  final bool iconOnly;

  @override
  State<SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<SignOutButton> {
  bool _busy = false;

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.controller.signOut();
    // No setState after: AuthGate swaps this subtree out on sign-out.
  }

  @override
  Widget build(BuildContext context) {
    final label = _busy ? 'Signing out...' : 'Sign Out';
    final indicator = _busy
        ? const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: kIndigo),
          )
        : const Icon(Icons.logout, size: 18, color: kIndigo);

    if (widget.iconOnly) {
      return IconButton(
        onPressed: _busy ? null : _signOut,
        tooltip: label,
        icon: indicator,
      );
    }

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kIndigo,
          ),
        ),
      ],
    );

    return widget.compact
        ? TextButton(onPressed: _busy ? null : _signOut, child: child)
        : OutlinedButton(
            onPressed: _busy ? null : _signOut,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: kBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child:
                SizedBox(width: double.infinity, child: Center(child: child)),
          );
  }
}
