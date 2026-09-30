import 'package:flutter/material.dart';

import 'main.dart';
import 'motion.dart';

/// Shown when a signed-in user reaches a route their permissions do not cover.
///
/// Deliberately distinct from the 404: telling the user "this exists but is
/// not yours" is correct here, because they are authenticated and an
/// administrator can grant access. It names the permission so a support
/// request can be specific, and nothing about the resource itself is
/// disclosed.
class UnauthorizedPage extends StatelessWidget {
  const UnauthorizedPage({
    super.key,
    required this.path,
    required this.onHome,
    this.requiredPermission,
  });

  /// The route that was refused.
  final String path;

  /// The permission that would have been needed, shown so the user can quote
  /// it when asking for access.
  final String? requiredPermission;

  /// Back to a page the user *can* open — the router decides which.
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCanvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeIn(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: semanticTint(kDanger),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: kDanger,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        header: true,
                        child: const Text(
                          'Access denied',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your account does not have permission to open this '
                        'page. Ask a platform administrator if you need access.',
                        style:
                            TextStyle(fontSize: 14, color: kMuted, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      _DetailRow(label: 'Page', value: path),
                      if (requiredPermission != null) ...[
                        const SizedBox(height: 8),
                        _DetailRow(
                          label: 'Requires',
                          value: requiredPermission!,
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onHome,
                          style: FilledButton.styleFrom(
                            backgroundColor: kIndigo,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Back to my dashboard'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One `label: value` line, monospaced so a path or permission id reads
/// exactly as it must be typed.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kInset,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Text(
            '$label  ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kMuted,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: kInk,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
