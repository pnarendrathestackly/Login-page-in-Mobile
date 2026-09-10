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

  test('demoCode mirrors the outstanding code and clears when consumed',
      () async {
    expect(auth.demoCode, isNull);
    await auth.signIn('me@stackly.com', 'password123');
    expect(auth.demoCode, code);
    await auth.verify(code!);
    // Consumed: nothing left to show.
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

  test('code is single-use', () async {
    await auth.signIn('me@stackly.com', 'password123');
    final used = code!;
    await auth.verify(used);
    await auth.signOut();
    await auth.signIn('me@stackly.com', 'password123');
    await auth.verify(used); // stale code from the previous session
    expect(auth.status, AuthStatus.awaitingVerification);
  });

  test('resend invalidates the previous code', () async {
    await auth.signIn('me@stackly.com', 'password123');
    final first = code!;
    await auth.resend();
    expect(code, isNot(first));
    await auth.verify(first);
    expect(auth.status, AuthStatus.awaitingVerification);
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
