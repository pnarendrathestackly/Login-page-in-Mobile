import 'package:flutter/material.dart';

import '../../../../../motion.dart';
import '../../../../../widgets/sidebar/app_sidebar.dart' show StacklyLogo;
import '../login_screen.dart' show OE;

/// The dark brand band shared by the auth pages: a short header above the form
/// on phones, a full-height panel beside it on desktop ([tall]).
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.tall = false});

  final bool tall;

  @override
  Widget build(BuildContext context) {
    if (!tall) return const _PhoneHeader();
    return Container(
      width: double.infinity,
      color: const Color(0xFF05060F),
      child: AmbientGlow(
          child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FadeIn(child: StacklyLogo()),
              const Spacer(),
              FadeIn(
                  delay: Motion.stagger * 2,
                  duration: Motion.complex,
                  child: Text(
                    'CLOUD PLATFORM  ·  HRMS  ·  CRM  ·  ERP  ·  FINANCE  ·  AI',
                    style: OE.mono.copyWith(
                      fontSize: 10.5,
                      letterSpacing: 2,
                      height: 1.9,
                      color: Colors.white.withValues(alpha: .45),
                    ),
                  )),
              const SizedBox(height: 14),
              FadeIn(
                  delay: Motion.stagger * 4,
                  duration: Motion.complex,
                  offset: 14,
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'One identity.\n'),
                        TextSpan(
                          text: 'Infinite ',
                          style: TextStyle(color: Color(0xFF4C7DFF)),
                        ),
                        TextSpan(text: 'Potential.'),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 40,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                      color: Colors.white,
                    ),
                  )),
              const Spacer(flex: 2),
            ],
          ),
        ),
      )),
    );
  }
}

/// The phone header, sized off the sign-in mock at 360 logical px wide: the
/// same logo, eyebrow and headline as the cover page, compacted.
class _PhoneHeader extends StatelessWidget {
  const _PhoneHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: AmbientGlow(
          child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 25.5, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: staggerIn([
              Image.asset(
                'assets/stackly_logo.png',
                height: 32,
                filterQuality: FilterQuality.medium,
                semanticLabel: 'Stackly',
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.only(left: 1.5),
                child: Text(
                  // Broken by hand where the mock breaks it, so the wrap does
                  // not depend on which monospace font the platform supplies.
                  'CLOUD PLATFORM  ·  HRMS  ·  CRM  ·  ERP  ·\nFINANCE  ·  AI',
                  style: OE.mono.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 1.3,
                    height: 11.7 / 9.5,
                    color: const Color(0xFF8A93A6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.only(left: 1.5),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'One identity.\n',
                        style: TextStyle(letterSpacing: 0),
                      ),
                      TextSpan(
                        text: 'Infinite ',
                        style: TextStyle(color: Color(0xFF4F7FF1)),
                      ),
                      TextSpan(text: 'Potential.'),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 27,
                    height: 29 / 27,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ]),
          ),
        ),
      )),
    );
  }
}
