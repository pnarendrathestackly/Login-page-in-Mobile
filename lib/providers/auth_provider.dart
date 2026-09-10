import '../auth.dart';

/// Provider-facing view of authentication.
///
/// ponytail: extends the existing [AuthController] rather than wrapping it.
/// The controller is already a ChangeNotifier with the whole auth contract on
/// it, so a wrapper would be a second copy of every getter that could drift.
/// This subclass exists only to add the single-step (password + OTP together)
/// sign-in the login form needs.
class AuthProvider extends AuthController {
  AuthProvider(super.backend);

  /// Signs in with the password AND the second factor in one submit, so the
  /// OTP can live on the login form instead of a separate screen.
  ///
  /// The password step is only run when there is no code outstanding. The
  /// backend issues a fresh code on every successful password check, which
  /// would invalidate the one the user is currently typing — so once a code
  /// has been sent, this verifies it rather than requesting another.
  ///
  /// A failure at either step leaves the user unauthenticated on the login
  /// form with a message, never half-way into a separate verify route.
  Future<void> signInWithCode({
    required String email,
    required String password,
    required String code,
  }) async {
    // True when this submit is what triggered the code being sent, so the
    // user cannot possibly have entered the right one yet.
    var codeJustSent = false;

    if (status != AuthStatus.awaitingVerification) {
      await signIn(email, password);
      // The password was rejected; signIn already surfaced why.
      if (status != AuthStatus.awaitingVerification) return;
      codeJustSent = true;
    }

    if (codeJustSent) {
      // Saying "incorrect code" here would be wrong: the code they typed was
      // never valid because the real one has only just been issued.
      // Deliberately does not claim the code was sent anywhere: there is no
      // mail or SMS service in this project, and telling the user to check an
      // inbox that will never receive anything is how this flow becomes
      // impossible to complete. A real backend should change this wording.
      setError('Enter the 6-digit code shown below to finish signing in.');
      return;
    }

    await verify(code);

    // A bad code must not leave a pending half-session hanging around: the
    // user is back on the login form, so the session state must say so too.
    // The message from verify() is preserved — cancelVerification clears it.
    if (status != AuthStatus.authenticated) {
      final message = error;
      await cancelVerification();
      setError(message);
    }
  }
}
