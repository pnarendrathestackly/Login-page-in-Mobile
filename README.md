# TheStackly — Two-Step Auth & Dashboard

A Flutter auth front end built to a supplied design mockup: split-panel
layout, client-side form validation, brand social buttons, a two-step
(password → OTP) sign-in flow, and an authenticated dashboard.

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

Demo credentials: `me@stackly.com` / `password123`. The generated code is
printed to the console (`DEMO OTP: ...`).


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

Pulls `flutter_svg` and `flutter_lints`.

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

27 tests:

| File | Covers |
|------|--------|
| `validators_test.dart` | Email and password rules. |
| `auth_test.dart` | OTP single-use, expiry, resend invalidating the previous code, attempt cap, sign-out, session expiry. |
| `flow_test.dart` | The real widget tree: password alone does not reach the dashboard, paste auto-verifies, sign-out returns to login. |
| `responsive_test.dart` | No layout overflow at phone / tablet / desktop widths; mobile drawer opens. |


## Project layout

| File | Responsibility |
|------|----------------|
| `lib/main.dart` | App entry, theme, brand colour constants, and `AuthGate` — the single place that maps auth state to a screen. |
| `lib/auth.dart` | `AuthStatus`, `AuthController` (state), `AuthBackend` (the seam a real server plugs into) and `DemoAuthBackend`. |
| `lib/widgets.dart` | Shared pieces: layout shell, form field, buttons, message banner, social row, validators. |
| `lib/login_page.dart` | Step 1 — email + password. |
| `lib/verify_page.dart` | Step 2 — OTP entry, resend countdown, back to sign-in. |
| `lib/otp_field.dart` | Six-box code input: auto-advance, paste, backspace navigation. |
| `lib/dashboard.dart` | Authenticated shell — sidebar, header, cards, sign-out. |
| `lib/signup_page.dart` | Registration form. |

## The two-step flow

    unauthenticated → authenticating → awaitingVerification → authenticated
                                       (password OK,          (OTP OK,
                                        NOT logged in)         dashboard)

`AuthGate` swaps screens on state rather than pushing routes, so there is no
navigation history to go "back" into after signing out, and a user in
`awaitingVerification` has no route to the dashboard at all.


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
