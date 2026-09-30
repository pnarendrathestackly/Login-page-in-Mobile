import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/widgets/common/file_export.dart';

/// The account operations added to [AuthBackend]: the rules live in the
/// backend, so they are tested there rather than through the widgets.
void main() {
  late DemoAuthBackend backend;
  setUp(() => backend = DemoAuthBackend(latency: Duration.zero));

  Future<void> expectAuthError(Future<Object?> f, String text) async {
    await expectLater(
      f,
      throwsA(isA<AuthException>()
          .having((e) => e.message, 'message', contains(text))),
    );
  }

  group('workspace', () {
    test('only the demo tenant exists', () async {
      expect(await backend.workspaceExists('acmecorp'), isTrue);
      expect(await backend.workspaceExists(' AcmeCorp '), isTrue);
      expect(await backend.workspaceExists('nope'), isFalse);
    });

    test('lookup by email', () async {
      expect(await backend.findWorkspace('me@stackly.com'), 'acmecorp');
      expect(await backend.findWorkspace('nobody@x.com'), isNull);
    });
  });

  group('change password', () {
    test('rejects a wrong current password', () async {
      await expectAuthError(
        backend.changePassword('me@stackly.com', 'wrong', 'newpass123'),
        'current password is incorrect',
      );
    });

    test('rejects a short or unchanged password', () async {
      await expectAuthError(
        backend.changePassword('me@stackly.com', 'password123', 'short'),
        'at least 8',
      );
      await expectAuthError(
        backend.changePassword('me@stackly.com', 'password123', 'password123'),
        'differs',
      );
    });

    test('the new password signs in; the old one no longer does', () async {
      await backend.changePassword(
          'me@stackly.com', 'password123', 'fresh-pass1');
      await backend.signIn('me@stackly.com', 'fresh-pass1');
      await expectAuthError(
        backend.signIn('me@stackly.com', 'password123'),
        'Incorrect email or password',
      );
    });
  });

  group('password reset', () {
    test('an unknown email is accepted silently (no enumeration)', () async {
      await backend.requestPasswordReset('nobody@x.com');
      await expectAuthError(
        backend.resetPassword(
            'nobody@x.com', DemoAuthBackend.demoCode, 'x' * 8),
        'invalid or has expired',
      );
    });

    test('a wrong code is refused and counts an attempt', () async {
      await backend.requestPasswordReset('me@stackly.com');
      await expectAuthError(
        backend.resetPassword('me@stackly.com', '000000', 'newpass123'),
        'Incorrect code',
      );
    });

    test('a code for one account cannot reset another', () async {
      await backend.requestPasswordReset('me@stackly.com');
      await expectAuthError(
        backend.resetPassword(
            'hr@onecloud.com', DemoAuthBackend.demoCode, 'newpass123'),
        'invalid or has expired',
      );
    });

    test('the right code sets the new password, once', () async {
      await backend.requestPasswordReset('me@stackly.com');
      await backend.resetPassword(
          'me@stackly.com', DemoAuthBackend.demoCode, 'newpass123');
      await backend.signIn('me@stackly.com', 'newpass123');
      // Single use: replaying the same code fails.
      await expectAuthError(
        backend.resetPassword(
            'me@stackly.com', DemoAuthBackend.demoCode, 'another123'),
        'invalid or has expired',
      );
    });
  });

  test('a deactivated account cannot sign in', () async {
    await backend.deactivateAccount('me@stackly.com');
    await expectAuthError(
      backend.signIn('me@stackly.com', 'password123'),
      'deactivated',
    );
    // A wrong password still reads as a wrong password.
    await expectAuthError(
      backend.signIn('me@stackly.com', 'nope'),
      'Incorrect email or password',
    );
  });

  test('a deleted account is gone', () async {
    await backend.deleteAccount('me@stackly.com');
    await expectAuthError(
      backend.signIn('me@stackly.com', 'password123'),
      'Incorrect email or password',
    );
    expect(await backend.findWorkspace('me@stackly.com'), isNull);
  });

  group('controller', () {
    test('changePassword reports the backend message', () async {
      final auth = AuthController(backend);
      expect(await auth.changePassword('a', 'b'), 'Your session has expired.');
    });

    test('checkWorkspace names an unknown workspace', () async {
      final auth = AuthController(backend);
      expect(await auth.checkWorkspace('acmecorp'), isNull);
      expect(await auth.checkWorkspace('nope'), contains('"nope"'));
    });
  });

  test('CSV fields are quoted and quotes doubled', () {
    expect(csvRow(['a', 'b,c', 'say "hi"', 3, null]),
        '"a","b,c","say ""hi""","3",""');
    expect(
        csvOf([
          'h1',
          'h2'
        ], [
          ['1', '2'],
        ]),
        '"h1","h2"\n"1","2"');
  });
}
