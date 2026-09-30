import 'package:flutter/material.dart';

import '../../../../../widgets/sidebar/app_sidebar.dart' show StacklyLogo;
import '../login_screen.dart' show OE;

/// The dark brand band shared by the auth pages: a short header above the form
/// on phones, a full-height panel beside it on desktop ([tall]).
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.tall = false});

  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF05060F),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 22, 24, tall ? 22 : 26),
          child: Column(
            mainAxisAlignment:
                tall ? MainAxisAlignment.center : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StacklyLogo(),
              if (tall) const Spacer() else const SizedBox(height: 20),
              Text(
                'CLOUD PLATFORM  ·  HRMS  ·  CRM  ·  ERP  ·  FINANCE  ·  AI',
                style: OE.mono.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 2,
                  height: 1.9,
                  color: Colors.white.withValues(alpha: .45),
                ),
              ),
              const SizedBox(height: 14),
              Text.rich(
                const TextSpan(
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
                  fontSize: tall ? 40 : 26,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.5,
                  color: Colors.white,
                ),
              ),
              if (tall) const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
