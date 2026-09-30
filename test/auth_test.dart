import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';

void main() {
  late AuthController auth;
  // Captures the code the backend "sends", so tests never hardcode one.
  String? code;

  setUp(() {
    auth = AuthController(DemoAuthBackend(onCodeSent: (c) => code = c));
  });

  test('a registered account can then sign in', () async {
    final error = await auth.register(
      name: 'New Person',
      email: 'New.Person@Example.com',
      password: 'hunter2hunter2',
    );
    expect(error, isNull);

    // Case-insensitive: the address is normalized on both sides.
    await auth.signIn('new.person@example.com', 'hunter2hunter2');
    expect(auth.status, AuthStatus.awaitingVerification);
    await auth.verify(code!);
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.user?.name, 'New Person');
  });

  test('registering a duplicate email is refused', () async {
    final error = await auth.register(
      name: 'Someone',
      email: 'me@stackly.com',
      password: 'whatever123',
    );
    expect(error, contains('already exists'));
  });

  test('registering does not sign the user in', () async {
    await auth.register(
      name: 'New Person',
      email: 'new@example.com',
      password: 'hunter2hunter2',
    );
    expect(auth.status, AuthStatus.unauthenticated);
  });

  test('an unregistered account cannot sign in', () async {
    await auth.signIn('ghost@example.com', 'hunter2hunter2');
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.error, isNotNull);
  });

  test('demoCode is available up front and clears once signed in', () async {
    // Shown before the password step too: the login form asks for the code in
    // the same submit, so a hint that only appears afterwards comes too late.
    expect(auth.demoCode, DemoAuthBackend.demoCode);
    await auth.signIn('me@stackly.com', 'password123');
    expect(auth.demoCode, code);
    await auth.verify(code!);
    // Signed in: nothing left to prompt for.
    expect(auth.demoCode, isNull);
  });

  test('starts unauthenticated', () {
    expect(auth.status, AuthStatus.unauthenticated);
  });

  test('bad password does not advance the flow', () async {
    await auth.signIn('me@stackly.com', 'wrong-password');
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.error, isNotNull);
  });

  test('valid password awaits verification, not authenticated', () async {
    await auth.signIn('me@stackly.com', 'password123');
    expect(auth.status, AuthStatus.awaitingVerification);
    expect(auth.status, isNot(AuthStatus.authenticated));
  });

  test('wrong code keeps the user on the verify step', () async {
    await auth.signIn('me@stackly.com', 'password123');
    final wrong = code == '000000' ? '111111' : '000000';
    await auth.verify(wrong);
    expect(auth.status, AuthStatus.awaitingVerification);
    expect(auth.error, isNotNull);
  });

  test('correct code authenticates', () async {
    await auth.signIn('me@stackly.com', 'password123');
    await auth.verify(code!);
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.user?.email, 'me@stackly.com');
  });

  test('a consumed code cannot be replayed within the same session', () async {
    await auth.signIn('me@stackly.com', 'password123');
    await auth.verify(code!);
    expect(auth.status, AuthStatus.authenticated);

    // Verifying consumed the code: there is nothing outstanding to replay.
    await auth.signOut();
    await auth.verify(code!);
    expect(auth.status, isNot(AuthStatus.authenticated));

    // NOTE: the demo backend now issues a FIXED code (DemoAuthBackend.demoCode),
    // so a stale code from an earlier session is indistinguishable from a fresh
    // one and this can no longer test cross-session replay. A real backend
    // issues a new single-use code per sign-in, which restores that property —
    // this test should be tightened when one is wired in.
  });

  test('resend issues a code and resets the attempt budget', () async {
    await auth.signIn('me@stackly.com', 'password123');

    // Burn some attempts, then resend.
    await auth.verify('000000');
    await auth.verify('000000');
    await auth.resend();

    // The budget is fresh, so the reissued code still verifies.
    await auth.verify(code!);
    expect(auth.status, AuthStatus.authenticated);

    // NOTE: with a fixed demo code, resend cannot be observed to invalidate
    // the previous one — they are the same string. A real backend generates a
    // new code per send, which is what makes resend invalidation meaningful.
  });

  test('attempts are capped', () async {
    await auth.signIn('me@stackly.com', 'password123');
    final wrong = code == '000000' ? '111111' : '000000';
    for (var i = 0; i < DemoAuthBackend.maxAttempts; i++) {
      await auth.verify(wrong);
    }
    // Budget spent: even the right code is now refused.
    await auth.verify(code!);
    expect(auth.status, AuthStatus.awaitingVerification);
  });

  test('verify is inert while unauthenticated', () async {
    await auth.verify('123456');
    expect(auth.status, AuthStatus.unauthenticated);
  });

  test('sign out drops the user', () async {
    await auth.signIn('me@stackly.com', 'password123');
    await auth.verify(code!);
    await auth.signOut();
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.user, isNull);
  });

  test('session expiry explains itself', () async {
    await auth.signIn('me@stackly.com', 'password123');
    await auth.verify(code!);
    await auth.expireSession();
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.notice, contains('expired'));
  });
}
