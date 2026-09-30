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

  test('a first submit with the correct demo code authenticates in one go',
      () async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    // Cold start: the user has never received a code, but the demo code is
    // fixed, so a code typed ahead of time is still the right one — this must
    // not be thrown away and asked for again.
    await auth.signInWithCode(
      email: 'me@stackly.com',
      password: 'password123',
      code: '123456',
    );
    expect(code, isNotNull);
    expect(auth.error, isNull);
    expect(auth.status, AuthStatus.authenticated);
  });

  test('a first submit with the wrong code reports it and issues one',
      () async {
    String? code;
    final auth = AuthProvider(
      DemoAuthBackend(onCodeSent: (c) => code = c, latency: Duration.zero),
    );
    await auth.signInWithCode(
      email: 'me@stackly.com',
      password: 'password123',
      code: '000000',
    );
    expect(code, isNotNull);
    expect(auth.error, isNotNull);
    // A bad code does not leave a half-finished session hanging around.
    expect(auth.status, AuthStatus.unauthenticated);
  });
}
