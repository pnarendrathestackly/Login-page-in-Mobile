import 'dart:async';

import 'package:flutter/foundation.dart';

import 'core/platform/permissions.dart';
import 'core/platform/tenant.dart';

/// Where the user is in the two-step flow.
///
/// [awaitingVerification] means the password was accepted but the second
/// factor is outstanding — it is NOT an authenticated state, and the guards in
/// `AuthGate` treat it as such.
enum AuthStatus {
  unauthenticated,
  authenticating,
  awaitingVerification,
  authenticated,
}

class AuthUser {
  const AuthUser({
    required this.name,
    required this.email,
    required this.role,
    this.tenant,
    this.roles = const [],
  });

  final String name;
  final String email;

  /// Primary role label, kept as a plain string because it is what the
  /// existing UI displays. Authorization never reads it — see [roles].
  final String role;

  /// The organization this session is scoped to. Null only for a principal
  /// that has not finished signing in.
  final Tenant? tenant;

  /// Every role held, resolved from what the backend returned. A user may hold
  /// more than one; permissions are the union.
  final List<PlatformRole> roles;

  /// What this user may do. Resolved once here rather than at each call site,
  /// so no screen re-derives authorization from role names.
  PermissionSet get permissions => PermissionSet.forRoles(
        roles.isEmpty ? [PlatformRole.parse(role)] : roles,
      );
}

/// Raised for anything the user should see a message about. The message is
/// always safe to display — no server internals reach the UI through it.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The seam a real backend plugs into.
///
/// Every method here is what a server would expose over HTTP. Implement this
/// against your API and the UI needs no changes.
abstract class AuthBackend {
  /// Creates an account. Throws [AuthException] if the email is taken.
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  });

  /// Verifies the password. Returns the user the OTP was sent to.
  Future<AuthUser> signIn(String email, String password);

  /// Issues a fresh code, invalidating any previous one.
  Future<void> sendCode(String email);

  /// Consumes the code. Throws [AuthException] on wrong/expired/locked out.
  Future<AuthUser> verifyCode(String email, String code);

  Future<void> signOut();
}

/// In-memory stand-in for a real auth server.
///
/// SECURITY: this is a demo. Every rule below — code generation, expiry,
/// attempt caps, resend cooldown — runs on the client, where a user controls
/// the process and can bypass all of it. It exists so the UI has something to
/// talk to and so the shape of the real contract is visible. Do not ship it.
/// Replace with an [AuthBackend] that calls a server.
class DemoAuthBackend implements AuthBackend {
  DemoAuthBackend(
      {this.onCodeSent, this.latency = const Duration(milliseconds: 600)});

  /// Demo-only hook so the UI can surface the code that a real deployment
  /// would send by email/SMS.
  final void Function(String code)? onCodeSent;

  /// Fake network delay, so loading states are visible. Widget tests set this
  /// to zero — a pending real timer never fires inside the test fake-async zone.
  final Duration latency;

  static const codeLength = 6;
  static const codeLifetime = Duration(minutes: 5);
  static const resendCooldown = Duration(seconds: 30);
  static const maxAttempts = 5;

  /// The code every sign-in accepts.
  ///
  /// Fixed rather than generated: this backend has no way to deliver a code,
  /// so a random one only has to be read back off the screen anyway. A
  /// constant makes the demo predictable and keeps tests from depending on
  /// what was generated.
  ///
  /// SECURITY: a fixed code is not a second factor at all — anyone who knows
  /// a password is through. That is acceptable ONLY because this whole backend
  /// is a stand-in. A real [AuthBackend] generates a single-use code
  /// server-side and never returns it to the client.
  static const demoCode = '123456';

  String? _code;

  /// Demo-only: the outstanding code, so the UI can display it in place of the
  /// email/SMS this project has no way to send.
  String? get lastCode => _code;

  DateTime? _issuedAt;
  int _attempts = 0;
  AuthUser? _pendingUser;

  // ponytail: in-memory user store, passwords in plain text. A real backend
  // stores a salted hash and never holds the password at all. Seeded with one
  // account so the app is usable without signing up first.
  final Map<String, ({String password, String name, PlatformRole role})>
      _users = {
    'me@stackly.com': (
      password: 'password123',
      name: 'Vishnu Vardhan',
      role: PlatformRole.superAdmin,
    ),
    'hr@onecloud.com': (
      password: 'password123',
      name: 'Priya Raman',
      role: PlatformRole.hrAdmin,
    ),
    'finance@onecloud.com': (
      password: 'password123',
      name: 'Daniel Okoro',
      role: PlatformRole.financeAdmin,
    ),
    'sales@onecloud.com': (
      password: 'password123',
      name: 'Mei Tanaka',
      role: PlatformRole.salesManager,
    ),
    'employee@onecloud.com': (
      password: 'password123',
      name: 'Sam Whitfield',
      role: PlatformRole.employee,
    ),
  };

  /// The tenant every demo account belongs to. A real backend derives this
  /// from the account, and the server — never the client — decides it.
  static const _demoTenant = Tenant(
    id: 'tnt_onecloud',
    name: 'OneCloud Industries',
  );

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    final normalized = email.trim().toLowerCase();
    if (_users.containsKey(normalized)) {
      throw const AuthException('An account with that email already exists.');
    }
    // Self-registration grants the least-privileged role. Elevation is an
    // administrative action, never something a sign-up form can request.
    const role = PlatformRole.employee;
    _users[normalized] =
        (password: password, name: name.trim(), role: role);
    return AuthUser(
      name: name.trim(),
      email: normalized,
      role: role.label,
      tenant: _demoTenant,
      roles: const [role],
    );
  }

  @override
  Future<AuthUser> signIn(String email, String password) async {
    await Future<void>.delayed(latency);
    final normalized = email.trim().toLowerCase();
    final record = _users[normalized];
    if (record == null || record.password != password) {
      throw const AuthException('Incorrect email or password.');
    }
    _pendingUser = AuthUser(
      name: record.name,
      email: normalized,
      role: record.role.label,
      tenant: _demoTenant,
      roles: [record.role],
    );
    await sendCode(normalized);
    return _pendingUser!;
  }

  @override
  Future<void> sendCode(String email) async {
    await Future<void>.delayed(latency);
    // Always the same code — see [demoCode]. Still assigned per send so the
    // expiry and attempt budget below behave exactly as a real flow would.
    _code = demoCode;
    _issuedAt = DateTime.now();
    _attempts = 0;
    // Stands in for the email/SMS a server would send.
    debugPrint('DEMO OTP: $_code');
    onCodeSent?.call(_code!);
  }

  @override
  Future<AuthUser> verifyCode(String email, String code) async {
    await Future<void>.delayed(latency);
    final issued = _issuedAt;
    if (_code == null || issued == null) {
      throw const AuthException('No code requested. Request a new one.');
    }
    if (DateTime.now().difference(issued) > codeLifetime) {
      _invalidate();
      throw const AuthException('That code has expired. Request a new one.');
    }
    if (_attempts >= maxAttempts) {
      _invalidate();
      throw const AuthException(
        'Too many incorrect attempts. Request a new code.',
      );
    }
    if (code != _code) {
      _attempts++;
      final left = maxAttempts - _attempts;
      throw AuthException(
        left > 0
            ? 'Incorrect code. $left ${left == 1 ? 'attempt' : 'attempts'} left.'
            : 'Too many incorrect attempts. Request a new code.',
      );
    }
    final user = _pendingUser!;
    _invalidate(); // single-use: the code cannot be replayed.
    return user;
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(latency);
    _invalidate();
    _pendingUser = null;
  }

  void _invalidate() {
    _code = null;
    _issuedAt = null;
    _attempts = 0;
  }
}

/// Single source of truth for auth state. Widgets listen; nothing else stores
/// a copy, so there is no stale authenticated state to go out of sync.
class AuthController extends ChangeNotifier {
  AuthController(this._backend);

  final AuthBackend _backend;

  AuthStatus _status = AuthStatus.unauthenticated;
  AuthUser? _user;
  String? _error;
  bool _busy = false;
  String? _notice;

  AuthStatus get status => _status;
  AuthUser? get user => _user;

  /// What the signed-in principal may do.
  ///
  /// Empty unless fully authenticated: a half-finished sign-in (password
  /// accepted, OTP outstanding) holds no permissions, so an interrupted login
  /// cannot be used to read anything.
  PermissionSet get permissions => _status == AuthStatus.authenticated
      ? (_user?.permissions ?? const PermissionSet.empty())
      : const PermissionSet.empty();

  /// The tenant this session is scoped to, or null when signed out.
  Tenant? get tenant =>
      _status == AuthStatus.authenticated ? _user?.tenant : null;

  /// The code the demo backend just "sent", so the verify screen can display
  /// it in debug builds. Null in release, and null for any real backend —
  /// a server never hands the code back to the client.
  String? get demoCode {
    if (kReleaseMode) return null;
    final backend = _backend;
    return backend is DemoAuthBackend ? backend.lastCode : null;
  }

  String? get error => _error;
  String? get notice => _notice;
  bool get busy => _busy;

  /// Email awaiting a second factor — the verify screen shows it, and it is
  /// the only thing carried between the two steps.
  String? get pendingEmail =>
      _status == AuthStatus.awaitingVerification ? _user?.email : null;

  /// Sets the message the auth screens display. Used when a multi-step sign-in
  /// has to unwind its own state but must keep the reason on screen.
  @protected
  void setError(String? message) {
    if (_error == message) return;
    _error = message;
    notifyListeners();
  }

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    if (_busy) return; // guards against duplicate submits
    _busy = true;
    _error = null;
    _notice = null;
    _status = AuthStatus.authenticating;
    notifyListeners();
    try {
      _user = await _backend.signIn(email, password);
      _status = AuthStatus.awaitingVerification;
    } on AuthException catch (e) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _error = e.message;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _error = 'Something went wrong. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Creates an account. Does not sign the user in — they return to the login
  /// screen and authenticate normally, so the OTP step is never skipped.
  /// Returns null on success, or a message to display.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_busy) return null;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _backend.register(name: name, email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not create the account. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> verify(String code) async {
    if (_busy || _status != AuthStatus.awaitingVerification) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _backend.verifyCode(_user!.email, code);
      _status = AuthStatus.authenticated;
    } on AuthException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Verification failed. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> resend() async {
    if (_busy || _status != AuthStatus.awaitingVerification) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _backend.sendCode(_user!.email);
      _notice = 'A new code is on its way.';
    } on AuthException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not resend the code. Please try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Abandons a half-finished sign-in ("Back to sign in").
  Future<void> cancelVerification() async {
    await _backend.signOut();
    _status = AuthStatus.unauthenticated;
    _user = null;
    _error = null;
    _notice = null;
    notifyListeners();
  }

  Future<void> signOut({String? notice}) async {
    _busy = true;
    notifyListeners();
    await _backend.signOut();
    _status = AuthStatus.unauthenticated;
    _user = null;
    _error = null;
    _notice = notice;
    _busy = false;
    notifyListeners();
  }

  /// Drops the session and sends the user back to sign-in with a reason shown.
  Future<void> expireSession() =>
      signOut(notice: 'Your session expired. Please sign in again.');
}
