import 'package:flutter/material.dart';

import 'main.dart';
import 'motion.dart';
import 'widgets.dart';

/// Shown for any unrecognized URL. Reuses the app's existing surface, brand
/// mark and button styles — no new visual language.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, required this.path, required this.onHome});

  /// The path that did not match, echoed back so a typo is obvious.
  final String path;

  /// Where "Go back" leads — the router decides whether that is the dashboard
  /// or the login screen, based on the session.
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
                      const BrandMark(),
                      const SizedBox(height: 28),
                      const Text(
                        '404',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: kIndigo,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Page not found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: kInk,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        path.isEmpty
                            ? "That page doesn't exist."
                            : "We couldn't find $path.",
                        style: const TextStyle(fontSize: 14, color: kMuted),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(label: 'Go back', onTap: onHome),
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
