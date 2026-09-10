# OneCloud — Enterprise Platform

*Unify People, Process, Data and Intelligence for a Smarter Tomorrow*

The Flutter client for the OneCloud enterprise platform: a two-step
(password → OTP) sign-in, a role-aware application shell, centralized
routing with permission guards, multi-tenancy, and a registry of 16
platform modules.

**Scope, stated plainly:** this repository is the client tier. There is no
server here — no API gateway, no microservices, no database, no message
broker. The interfaces those attach to exist and are documented in
[ARCHITECTURE.md](ARCHITECTURE.md), which also lists exactly what is built
and what is not. Most module pages are routed and permission-checked but
have no screen yet; they say so on screen rather than showing invented
data.

## ⚠️ The OTP backend is a demo, not security

There is no server in this project. `DemoAuthBackend` (`lib/auth.dart`)
generates codes, expires them, caps attempts and enforces a resend cooldown
**entirely on the client** — where the user controls the process and can
bypass every one of those rules. It exists so the UI has something to talk to
and so the shape of the real contract is visible.

**Do not ship it.** Implement the `AuthBackend` interface against a real
server and pass it to `AuthController`; no UI changes are needed:

```dart
AuthController(MyHttpAuthBackend())   // lib/main.dart
```

A real implementation must generate the OTP server-side, keep it short-lived
and single-use, rate-limit issuance and verification, and hold the session in
an HttpOnly + Secure + SameSite cookie. Route protection has to be enforced
server-side too — the `AuthGate` in this app is a UX guard, not a security
boundary.

Demo accounts, all with password `password123`. They exist to exercise the
role system — each sees a different sidebar and is refused different routes:

| Email | Role |
|---|---|
| `me@stackly.com` | Super Admin (everything) |
| `hr@onecloud.com` | HR Admin |
| `finance@onecloud.com` | Finance Admin |
| `sales@onecloud.com` | Sales Manager |
| `employee@onecloud.com` | Employee (least privilege) |

The generated OTP is printed to the console (`DEMO OTP: ...`).

⚠️ Role and permission checks in this client are **UX guards, not security** —
they decide what is shown, never what is permitted. A real deployment must
re-authorize every request server-side. See [ARCHITECTURE.md](ARCHITECTURE.md) §5.


## Running it

Assumes Flutter 3.x with the Dart SDK it ships with.

### 1. Check the toolchain

    flutter --version
    flutter doctor

Resolve anything `doctor` flags for the platform you intend to run on before
continuing.

### 2. Fetch dependencies

    cd Login_Page
    flutter pub get

Pulls `provider` and `flutter_lints`.

### 3. Pick a device

    flutter devices

The split-panel layout is best seen on a wide target — Windows desktop or
Chrome. On a phone the illustration panel is intentionally hidden.

### 4. Run

    flutter run                  # default device
    flutter run -d windows       # wide layout
    flutter run -d chrome        # wide layout, no toolchain setup

In the terminal: `r` hot reload, `R` hot restart, `q` quit.

### 5. Run the tests

    flutter test

189 tests:

| File | Covers |
|------|--------|
| `validators_test.dart` | Email and password rules. |
| `auth_test.dart` | OTP single-use, expiry, resend invalidating the previous code, attempt cap, sign-out, session expiry. |
| `flow_test.dart` | The real widget tree: password alone does not reach the dashboard, paste auto-verifies, sign-out returns to login. |
| `permissions_test.dart` | Grants and denials, module-registry consistency, guard rules, tenant scoping. |
| `rbac_flow_test.dart` | Authorization end-to-end through the real router: what each role can open and is refused. |
| `router_test.dart`, `navigation_test.dart` | Routing, deep links, sidebar highlight following the URL. |
| `pages_test.dart`, `responsive_test.dart` | No layout overflow at 375–1920px; mobile drawer opens. |

Writing new widget tests: the shell animates continuously, so `pumpAndSettle`
never returns — use the bounded `step()` helper the suite already has, and
`unawaited()` for auth calls.


## Project layout

| File | Responsibility |
|------|----------------|
| `lib/main.dart` | App entry, theme, brand colour constants, provider registration. |
| `lib/router/app_router.dart` | **The** routing source of truth: route names, table, guards, page stack. |
| `lib/core/platform/permissions.dart` | Permission vocabulary, 15 roles, resolved `PermissionSet`. |
| `lib/core/platform/modules.dart` | The 16-module registry — one entry gives a page its route, sidebar row and permission. |
| `lib/core/platform/tenant.dart` | Tenant identity for multi-tenancy. |
| `lib/auth.dart` | `AuthStatus`, `AuthController`, `AuthBackend` (the seam a real server plugs into), `DemoAuthBackend`. |
| `lib/dashboard.dart` | Authenticated shell — sidebar, header, section and module page dispatch. |
| `lib/features/` | Per-domain screens. |
| `lib/widgets/` | Sidebar, header and shared UI. |
| `lib/otp_field.dart` | Six-box code input: auto-advance, paste, backspace navigation. |
| `lib/signup_page.dart` | Registration form. |

## The two-step flow

    unauthenticated → authenticating → awaitingVerification → authenticated
                                       (password OK,          (OTP OK,
                                        NOT logged in)         dashboard)

`applyGuards` in the router decides this, and it is the only place that does.
A user in `awaitingVerification` holds no permissions and has no route to the
dashboard at all; signing out re-runs the guards, so an expired session leaves
a protected screen on its own.


## How the layout works

Neither page holds layout code of its own. Both hand a hero and a form to one
shared shell, so the pages stay readable and the design lives in a single place.

    AuthScaffold          // the white card: 45/55 split, max-width 1180
    ├── AuthHero          // left: brand mark, headline, subtitle, artwork
    └── Form              // right: nav links + the page's own fields

Above 900 px the card renders as a split panel. Below 900 px the illustration
panel is dropped and the form takes the full width.

### AuthScaffold — `widgets.dart:8`

Centres a rounded white card in the viewport and splits it with a `Row` at
`flex: 45` / `flex: 55`. The card fills the viewport height; only the form
column scrolls, so the illustration never shifts while a user tabs through
fields.

### AuthHero — `widgets.dart:85`

Takes `title` as a list of lines plus an optional `highlight` line rendered in
indigo — that is how "Good / to see you / *again!*" gets its two-tone treatment
without any rich-text markup.

The artwork uses `BoxFit.fitWidth` inside a `ClipRect` so it spans the full
panel width and bleeds off the bottom edge. An earlier attempt with
`BoxFit.cover` cropped the sides at narrow window widths.

### AuthField — `widgets.dart:228`

A `TextFormField` wrapper, and the only stateful widget in the shared file. It
owns one piece of state: whether the password is currently masked, toggled by
the eye icon in the suffix.


## Validation

Both validators live in `widgets.dart` so the two forms share one definition,
and both are covered by unit tests.

| Validator | Rule |
|-----------|------|
| `emailValidator` | Required; must match `something@something.tld`. Leading and trailing whitespace is trimmed before checking. |
| `passwordValidator` | Required; minimum 8 characters. |

The sign-up page adds two inline rules of its own: first and last name must be
non-empty, and the confirm field must equal the password field.


## Brand logos

Google, GitHub and Microsoft marks are PNGs in `assets/`, registered in
`pubspec.yaml` and rendered logo-only (no caption). Each button keeps a
tooltip and a `Semantics` label — an icon-only button with no accessible name
is unusable with a screen reader.


## Assets

| File | Used by |
|------|---------|
| `assets/Loginpage.jpeg` | Login hero — used as supplied. |
| `assets/signup_art.jpg` | Sign-up hero — cropped from the original. |

**Why the sign-up art is cropped.** The supplied `signuppage.jpeg` was a full
mockup with the TheStackly logo, headline and subtitle baked into its top
third. Using it whole made that text appear twice on screen — once from the
image, once from the widgets. The top 34% was cropped off, leaving just the
desk scene.


## Android build note

If an Android build fails while trying to install an NDK version, that is the
Gradle plugin's auto-install path calling a `sdkmanager` that crashes on some
Windows setups. The fix already applied is to pin `ndkVersion` in
`android/app/build.gradle.kts` to the NDK actually installed, rather than
letting `flutter.ndkVersion` trigger the download.


## Where to wire the backend

Implement `AuthBackend` (`lib/auth.dart`) and pass it to `AuthController` in
`lib/main.dart`. That is the only change needed — sign-up, sign-in, OTP and
sign-out all route through that one interface.


## Known limits

- **`DemoAuthBackend` is not secure** — see the warning at the top.
- Accounts live in an in-memory map with plain-text passwords and are lost on
  restart. One account is seeded so the app works before signing up.
- The three social buttons are visual only — their handlers are empty.
- "Forgot password?" is not wired to a route.
- "Remember me" holds state but nothing persists it, so a refresh returns to
  the login screen. Real session persistence belongs in the backend.
- Session expiry exists as `AuthController.expireSession()` but nothing calls
  it — a real backend would trigger it on a 401.

## Getting the demo OTP

The demo backend generates the code **in the running app** — nothing is emailed
or sent anywhere.

**The code is shown on the login screen itself**, in an amber banner directly
above the six OTP boxes. It appears only after the password step, because the
code is created *by* that first submit:

1. Enter `me@stackly.com` / `password123`, leave the OTP boxes empty, click
   **Sign In**.
2. The banner appears: `Demo code: 483927`.
3. Type it into the boxes and click **Sign In** again.

On web, `debugPrint` goes to the **browser console** (F12 → Console), not the
terminal running `flutter run` — so the on-screen banner is the reliable place
to look. On Windows desktop (`flutter run -d windows`) it does print to the
terminal.

It will not appear in a release build: `debugPrint` is stripped and the
on-screen hint is suppressed by `kReleaseMode`, so a shipped build never leaks
the code. That also means a release build cannot be signed into without a real
`AuthBackend`.
