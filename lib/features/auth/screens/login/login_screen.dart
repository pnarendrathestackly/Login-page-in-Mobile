import 'package:flutter/material.dart';

import '../../../../widgets.dart';
import 'widgets/login_form.dart';

/// Login page layout only. The form (and the whole sign-in, OTP included)
/// lives in [LoginForm]; auth state lives in AuthProvider.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScaffold(
      left: AuthHero(
        title: ['Good', 'to see you'],
        image: 'assets/Loginpage.jpeg',
        highlight: 'again!',
        subtitle: 'Log in to continue your\nlearning journey.',
      ),
      form: LoginForm(),
    );
  }
}
