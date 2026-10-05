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
  const AuthException(this.message, {this.detail, this.lockedUntil});
  final String message;

  /// A secondary line under [message] — e.g. how many attempts are left.
  final String? detail;

  /// When a lockout lifts. Set only on the locked-out rejection, so the UI can
  /// show the lock screen and count down to it.
  final DateTime? lockedUntil;

  @override
  String toString() => detail == null ? message : '$message $detail';
}

/// The seam a real backend plugs into.
///
/// Every method here is what a server would expose over HTTP. Implement this
/// against your API and the UI needs no changes.
abstract class AuthBackend {
  /// Creates an account. Throws [AuthException] if the email is taken.
  ///
  /// [organization], [workspace], [mobile] and [username] come from the
  /// sign-up wizard. They are optional so an existing caller (or a backend
  /// that does not model them) keeps working.
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
    String? organization,
    String? workspace,
    String? mobile,
    String? username,
  });

  /// Verifies the password. Returns the user the OTP was sent to.
  Future<AuthUser> signIn(String email, String password);

  /// Issues a fresh code, invalidating any previous one.
  Future<void> sendCode(String email);

  /// Consumes the code. Throws [AuthException] on wrong/expired/locked out.
  Future<AuthUser> verifyCode(String email, String code);

  Future<void> signOut();

  /// Whether a workspace with this slug exists.
  Future<bool> workspaceExists(String slug);

  /// The workspace slug for an account, or null when there is none.
  Future<String?> findWorkspace(String email);

  /// Replaces the password. Throws [AuthException] if [current] is wrong or
  /// [next] breaks the password rules.
  Future<void> changePassword(String email, String current, String next);

  /// Issues a reset code when the account exists. Completes normally either
  /// way, so the response never reveals which emails have accounts.
  Future<void> requestPasswordReset(String email);

  /// Consumes a reset code and sets [next] as the password.
  Future<void> resetPassword(String email, String code, String next);

  /// Disables the account; sign-in is refused until an admin re-enables it.
  Future<void> deactivateAccount(String email);

  /// Permanently removes the account.
  Future<void> deleteAccount(String email);
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

  /// How long an account stays locked after [maxAttempts] failures.
  static const lockoutDuration = Duration(minutes: 15);

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
  /// Accounts an administrator has to re-enable before they can sign in.
  final Set<String> _deactivated = {};

  /// The email a password-reset code was issued for, so a code issued for one
  /// account cannot reset another.
  String? _resetEmail;

  static const minPasswordLength = 8;

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
    'vishnu@gmail.com': (
      password: 'Vishnu@123',
      name: 'Vishnu',
      role: PlatformRole.superAdmin,
    ),
    'narendra@gmail.com': (
      password: 'Narendra@123',
      name: 'Narendra',
      role: PlatformRole.superAdmin,
    ),
    'narendra@mail.com': (
      password: 'Narendra@123',
      name: 'Narendra',
      role: PlatformRole.superAdmin,
    ),
  };

  /// The tenant every demo account belongs to. A real backend derives this
  /// from the account, and the server — never the client — decides it.
  static const _demoTenant = Tenant(
    id: 'tnt_onecloud',
    name: 'OneCloud Industries',
    slug: 'acmecorp',
  );

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
    String? organization,
    String? workspace,
    String? mobile,
    String? username,
  }) async {
    await Future<void>.delayed(latency);
    final normalized = email.trim().toLowerCase();
    if (_users.containsKey(normalized)) {
      throw const AuthException('An account with that email already exists.');
    }
    final handle = username?.trim().toLowerCase();
    if (handle != null &&
        handle.isNotEmpty &&
        _usernames.values.contains(handle)) {
      throw const AuthException('That username is already taken.');
    }

    // The role is decided HERE, never requested by the form: whoever creates a
    // brand-new organization owns it, everyone else joins as an employee. A
    // sign-up that could name its own role would be a privilege escalation.
    final org = organization?.trim() ?? '';
    final firstInOrg = org.isNotEmpty &&
        !_organizations.values.any((o) => o.toLowerCase() == org.toLowerCase());
    final role =
        firstInOrg ? PlatformRole.superAdmin : PlatformRole.employee;

    _users[normalized] = (password: password, name: name.trim(), role: role);
    if (org.isNotEmpty) _organizations[normalized] = org;
    if (mobile != null && mobile.trim().isNotEmpty) {
      _mobiles[normalized] = mobile.trim();
    }
    if (handle != null && handle.isNotEmpty) _usernames[normalized] = handle;

    final ws = workspace?.trim() ?? '';
    final slug = _slug(ws.isNotEmpty ? ws : org);
    final tenant = slug.isEmpty
        ? _demoTenant
        : Tenant(id: 'tnt_$slug', name: org.isEmpty ? ws : org, slug: slug);
    _tenants[normalized] = tenant;

    return AuthUser(
      name: name.trim(),
      email: normalized,
      role: role.label,
      tenant: tenant,
      roles: [role],
    );
  }

  /// The workspace each registered account signs in under. Seeded accounts
  /// are absent and fall back to [_demoTenant].
  final Map<String, Tenant> _tenants = {};

  Tenant _tenantFor(String email) => _tenants[email] ?? _demoTenant;

  /// "ABC Technologies Pvt Ltd" -> "abctechnologiespvtltd", the workspace
  /// slug a new organization signs in under.
  static String _slug(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Profile details captured at sign-up, keyed by email.
  final Map<String, String> _organizations = {};
  final Map<String, String> _mobiles = {};
  final Map<String, String> _usernames = {};

  /// Failed password attempts per account, so the form can warn before the
  /// lockout the sign-in footer promises. Cleared on a successful password.
  final Map<String, int> _passwordAttempts = {};

  /// When each locked-out account becomes usable again. A lock that never
  /// lifted would need an administrator for every mistyped password.
  final Map<String, DateTime> _lockedUntil = {};

  @override
  Future<AuthUser> signIn(String email, String password) async {
    await Future<void>.delayed(latency);
    final normalized = email.trim().toLowerCase();
    final record = _users[normalized];

    final until = _lockedUntil[normalized];
    if (until != null) {
      if (DateTime.now().isBefore(until)) {
        throw AuthException(
          'Too many failed attempts.',
          detail: 'This account is locked. Try again later or reset your '
              'password.',
          lockedUntil: until,
        );
      }
      // The lock has expired: clear it and let this attempt through.
      _lockedUntil.remove(normalized);
      _passwordAttempts.remove(normalized);
    }

    if (record == null || record.password != password) {
      // Counted against the address whether or not it exists, so a wrong
      // guess cannot use the attempt count to learn that an account is real.
      final used = (_passwordAttempts[normalized] ?? 0) + 1;
      _passwordAttempts[normalized] = used;
      final left = maxAttempts - used;
      if (left > 0) {
        throw AuthException(
          'Incorrect email or password.',
          detail: '$left ${left == 1 ? 'attempt' : 'attempts'} remaining '
              'before lockout.',
        );
      }
      final locked = DateTime.now().add(lockoutDuration);
      _lockedUntil[normalized] = locked;
      throw AuthException(
        'Too many failed attempts.',
        detail: 'This account is locked. Try again later or reset your '
            'password.',
        lockedUntil: locked,
      );
    }
    _passwordAttempts.remove(normalized);
    // Checked only after the password, so a wrong guess cannot learn that an
    // account exists but is disabled.
    if (_deactivated.contains(normalized)) {
      throw const AuthException(
        'This account is deactivated. Contact your administrator.',
      );
    }
    _pendingUser = AuthUser(
      name: record.name,
      email: normalized,
      role: record.role.label,
      tenant: _tenantFor(normalized),
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
    _checkCode(code);
    final user = _pendingUser!;
    _invalidate(); // single-use: the code cannot be replayed.
    return user;
  }

  /// Expiry, attempt budget and match — shared by sign-in and password reset.
  void _checkCode(String code) {
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
    _resetEmail = null;
  }

  void _checkPassword(String password) {
    if (password.length < minPasswordLength) {
      throw const AuthException(
        'Password must be at least $minPasswordLength characters.',
      );
    }
  }

  @override
  Future<bool> workspaceExists(String slug) async {
    await Future<void>.delayed(latency);
    final s = slug.trim().toLowerCase();
    return s == _demoTenant.slug || _tenants.values.any((t) => t.slug == s);
  }

  // SECURITY: answering with the workspace reveals which emails have accounts.
  // Acceptable only in this demo, which cannot send email; a real server
  // emails the workspace link and gives every caller the same response.
  @override
  Future<String?> findWorkspace(String email) async {
    await Future<void>.delayed(latency);
    final key = email.trim().toLowerCase();
    return _users.containsKey(key) ? _tenantFor(key).slug : null;
  }

  @override
  Future<void> changePassword(
    String email,
    String current,
    String next,
  ) async {
    await Future<void>.delayed(latency);
    final key = email.trim().toLowerCase();
    final record = _users[key];
    if (record == null || record.password != current) {
      throw const AuthException('Your current password is incorrect.');
    }
    _checkPassword(next);
    if (next == current) {
      throw const AuthException(
        'Choose a new password that differs from the current one.',
      );
    }
    _users[key] = (password: next, name: record.name, role: record.role);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await Future<void>.delayed(latency);
    final key = email.trim().toLowerCase();
    if (!_users.containsKey(key)) return; // same response: no enumeration
    await sendCode(key);
    _resetEmail = key;
  }

  @override
  Future<void> resetPassword(String email, String code, String next) async {
    await Future<void>.delayed(latency);
    final key = email.trim().toLowerCase();
    if (_resetEmail != key) {
      // Same wording as a wrong code, so this does not reveal whether the
      // email has an account.
      throw const AuthException(
        'That code is invalid or has expired. Request a new one.',
      );
    }
    _checkCode(code);
    _checkPassword(next);
    final record = _users[key]!;
    _users[key] = (password: next, name: record.name, role: record.role);
    _invalidate();
  }

  @override
  Future<void> deactivateAccount(String email) async {
    await Future<void>.delayed(latency);
    final key = email.trim().toLowerCase();
    if (!_users.containsKey(key)) {
      throw const AuthException('That account no longer exists.');
    }
    _deactivated.add(key);
  }

  @override
  Future<void> deleteAccount(String email) async {
    await Future<void>.delayed(latency);
    final key = email.trim().toLowerCase();
    if (_users.remove(key) == null) {
      throw const AuthException('That account no longer exists.');
    }
    _deactivated.remove(key);
    _tenants.remove(key);
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
  String? _errorDetail;
  DateTime? _lockedUntil;
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

  /// The code the demo backend accepts, so the login form can display it in
  /// debug builds. Null in release, and null for any real backend — a server
  /// never hands the code back to the client.
  ///
  /// Reports the demo backend's FIXED code rather than only the outstanding
  /// one: the code is a constant, and the login form asks for it in the same
  /// submit as the password. Gating this on a code having already been "sent"
  /// meant the hint only appeared after a failed sign-in, which is exactly
  /// when the user no longer needs telling.
  String? get demoCode {
    if (kReleaseMode) return null;
    final backend = _backend;
    if (backend is! DemoAuthBackend) return null;
    // Once signed in there is nothing left to prompt for, so the hint goes
    // away rather than sitting on the dashboard.
    if (_status == AuthStatus.authenticated) return null;
    return backend.lastCode ?? DemoAuthBackend.demoCode;
  }

  String? get error => _error;

  /// Second line under [error], when the backend supplied one (for example
  /// how many sign-in attempts remain).
  String? get errorDetail => _errorDetail;

  /// When the current lockout lifts, or null when the account is not locked.
  DateTime? get lockedUntil =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)
          ? _lockedUntil
          : null;
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

  void clearError() => setError(null);

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    if (_busy) return; // guards against duplicate submits
    _busy = true;
    _error = null;
    _errorDetail = null;
    _lockedUntil = null;
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
      _errorDetail = e.detail;
      _lockedUntil = e.lockedUntil;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _error = 'Something went wrong. Please try again.';
      _errorDetail = null;
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
    String? organization,
    String? workspace,
    String? mobile,
    String? username,
  }) async {
    if (_busy) return null;
    _busy = true;
    _error = null;
    _errorDetail = null;
    _lockedUntil = null;
    notifyListeners();
    try {
      await _backend.register(
        name: name,
        email: email,
        password: password,
        organization: organization,
        workspace: workspace,
        mobile: mobile,
        username: username,
      );
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
    _errorDetail = null;
    _lockedUntil = null;
    notifyListeners();
    try {
      _user = await _backend.verifyCode(_user!.email, code);
      _status = AuthStatus.authenticated;
    } on AuthException catch (e) {
      _error = e.message;
      _errorDetail = e.detail;
      _lockedUntil = e.lockedUntil;
    } catch (_) {
      _error = 'Verification failed. Please try again.';
      _errorDetail = null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> resend() async {
    if (_busy || _status != AuthStatus.awaitingVerification) return;
    _busy = true;
    _error = null;
    _errorDetail = null;
    _lockedUntil = null;
    notifyListeners();
    try {
      await _backend.sendCode(_user!.email);
      _notice = 'A new code is on its way.';
    } on AuthException catch (e) {
      _error = e.message;
      _errorDetail = e.detail;
      _lockedUntil = e.lockedUntil;
    } catch (_) {
      _error = 'Could not resend the code. Please try again.';
      _errorDetail = null;
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
    _errorDetail = null;
    _lockedUntil = null;
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
    _errorDetail = null;
    _lockedUntil = null;
    _notice = notice;
    _busy = false;
    notifyListeners();
  }

  /// Drops the session and sends the user back to sign-in with a reason shown.
  Future<void> expireSession() =>
      signOut(notice: 'Your session expired. Please sign in again.');

  /// Runs one account operation with the shared busy flag (so a second click
  /// cannot queue a duplicate) and turns failures into a message. Returns
  /// null on success, otherwise the message to show.
  Future<String?> _attempt(
    Future<void> Function() op,
    String fallback,
  ) async {
    if (_busy) return 'Please wait for the current request to finish.';
    _busy = true;
    notifyListeners();
    try {
      await op();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return fallback;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Null when the workspace exists, otherwise why it cannot be used.
  Future<String?> checkWorkspace(String slug) async {
    var exists = false;
    final error = await _attempt(
      () async => exists = await _backend.workspaceExists(slug),
      "We couldn't check that workspace. Please try again.",
    );
    return error ??
        (exists ? null : "We couldn't find a workspace called \"$slug\".");
  }

  /// The workspace for [email]: `(slug, null)` or `(null, message)`.
  Future<(String?, String?)> findWorkspace(String email) async {
    String? slug;
    final error = await _attempt(
      () async => slug = await _backend.findWorkspace(email),
      "We couldn't look up your workspace. Please try again.",
    );
    if (error != null) return (null, error);
    return slug == null
        ? (null, 'No workspace is linked to that email address.')
        : (slug, null);
  }

  Future<String?> changePassword(String current, String next) {
    final email = _user?.email;
    if (email == null) return Future.value('Your session has expired.');
    return _attempt(
      () => _backend.changePassword(email, current, next),
      "We couldn't change your password. Please try again.",
    );
  }

  Future<String?> requestPasswordReset(String email) => _attempt(
        () => _backend.requestPasswordReset(email),
        "We couldn't start the reset. Please try again.",
      );

  Future<String?> resetPassword(String email, String code, String next) =>
      _attempt(
        () => _backend.resetPassword(email, code, next),
        "We couldn't reset your password. Please try again.",
      );

  /// Deactivates the signed-in account, then signs out.
  Future<String?> deactivateAccount() async {
    final email = _user?.email;
    if (email == null) return 'Your session has expired.';
    final error = await _attempt(
      () => _backend.deactivateAccount(email),
      "We couldn't deactivate your account. Please try again.",
    );
    if (error == null) {
      await signOut(notice: 'Your account has been deactivated.');
    }
    return error;
  }

  /// Deletes the signed-in account, then signs out.
  Future<String?> deleteAccount() async {
    final email = _user?.email;
    if (email == null) return 'Your session has expired.';
    final error = await _attempt(
      () => _backend.deleteAccount(email),
      "We couldn't delete your account. Please try again.",
    );
    if (error == null) {
      await signOut(notice: 'Your account has been deleted.');
    }
    return error;
  }
}
