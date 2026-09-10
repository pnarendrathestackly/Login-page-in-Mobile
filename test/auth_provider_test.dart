import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/providers/auth_provider.dart';

void main() {
  test('signInWithCode authenticates with a valid code', () async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    // First sign-in issues the code.
    await auth.signIn('me@stackly.com', 'password123');
    expect(auth.status, AuthStatus.awaitingVerification);
    expect(code, isNotNull);

    await auth.signInWithCode(
      email: 'me@stackly.com',
      password: 'password123',
      code: code!,
    );
    expect(auth.error, isNull);
    expect(auth.status, AuthStatus.authenticated);
  });

  test('a first submit with no code yet reports it and issues one', () async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    // Cold start: the user has never received a code.
    await auth.signInWithCode(
      email: 'me@stackly.com',
      password: 'password123',
      code: '123456',
    );
    // A code is now on its way, and the user is told what happened.
    expect(code, isNotNull);
    expect(auth.error, contains('sent you a code'));
    expect(auth.status, AuthStatus.awaitingVerification);
  });
}
