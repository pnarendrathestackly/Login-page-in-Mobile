# OneCloud — Architecture

This document describes what the code in this repository actually does, and
draws a hard line between that and the target architecture it is being built
toward. Anything under "Not built" is not present in this repo — do not plan
against it as if it were.

---

## 1. What this repository is

A Flutter application: the **client tier** of the OneCloud platform, with a
demo in-process backend behind a replaceable interface.

There is **no server in this repository.** No API gateway, no microservices,
no database, no message broker. The seams where those attach exist and are
described below.

---

## 2. Layers, and their status

| Layer | Status | Where |
|---|---|---|
| Client (web/desktop/mobile shell) | **Built** | `lib/` |
| Central routing + guards | **Built** | `lib/router/app_router.dart` |
| Identity & access (RBAC, tenancy) | **Built, client-side** | `lib/core/platform/` |
| Module registry (16 modules) | **Built** | `lib/core/platform/modules.dart` |
| Module screens | **Routed, mostly unimplemented** | `lib/features/` |
| Auth backend | **Demo only** | `lib/auth.dart` |
| Data layer | **Demo only** | `lib/features/dashboard/services/` |
| API gateway | Not built | — |
| Domain microservices | Not built | — |
| Event streaming | Not built | — |
| PostgreSQL / Redis / search / object store | Not built | — |
| Observability, CI/CD, Kubernetes | Not built | — |

---

## 3. Data flow as implemented

```
Widget
  ↓  reads state from
Provider (AuthProvider / NavigationProvider)
  ↓  calls
Repository interface  (AuthBackend, DashboardRepository)
  ↓  currently bound to
Demo in-memory implementation
```

The target flow inserts an HTTP client and the gateway between the repository
interface and the data:

```
Repository interface
  ↓
API client  (one, centralized — not yet written)
  ↓
API Gateway → authn/authz → domain service → database
                              ↓
                         event publisher → broker → consumers
```

**The interfaces are the seam.** `AuthBackend` and `DashboardRepository` are
pure abstract classes. Implementing either against HTTP requires no change to
any widget, provider or route — that is the whole point of their existing.

---

## 4. Routing

`lib/router/app_router.dart` is the single source of truth. Nothing else in the
app holds a path string.

- **Route names** — `AppRoutes` constants; no literals anywhere else.
- **Route table** — `_resolve()`. Module routes (`/<module>/<page>`) resolve
  from the registry; legacy top-level routes resolve from a `switch`.
- **Guards** — `applyGuards()`. The *only* place access is decided.
- **Page stack** — `_pagesFor()`. Section routes and module routes share one
  shell page with a stable key, so moving between destinations reuses the shell
  element rather than remounting and refetching.

### Guard rules

| Session state | Request | Result |
|---|---|---|
| Authenticated | permitted route | allowed |
| Authenticated | route needing a permission they lack | `/403` |
| Authenticated | `/login`, `/register` | → dashboard |
| Authenticated | unknown page under a real module | `/404` |
| Awaiting OTP | any protected route | → `/login` |
| Signed out | any protected route | → `/login` |
| Signed out | `/404` | `/404` (a typo is not hidden behind a login form) |

`/404` and `/403` are deliberately distinct: 403 tells an authenticated user
the page exists and can be requested from an admin; 404 says nothing.

### Legacy paths

`/reports` and `/notifications` predate the module registry and have working
screens. Their modules declare `legacyPath`, which keeps those URLs canonical
and suppresses the duplicate module route and the duplicate sidebar row. A test
asserts no two registry pages resolve to the same path.

---

## 5. Authorization

Three types, in `lib/core/platform/permissions.dart`:

- **`Perm`** — the permission vocabulary, `module.action` strings. Every check
  names a constant, so a typo fails to compile rather than silently denying.
- **`PlatformRole`** — 15 roles, each a *set of permissions*. Roles are a
  grouping convenience; nothing in the app authorizes on a role name, so
  deployments can add roles without touching screens.
- **`PermissionSet`** — the resolved, immutable grant set for the session.
  `can` / `canAny` / `canAll`. `*` (Super Admin) short-circuits everything.

Enforced at four levels:

1. **Route** — `applyGuards`, before the page is built.
2. **Sidebar** — `visibleModules` / `visiblePages`; a user is never shown a
   destination that would refuse them.
3. **Landing** — `homePathFor` picks a page the principal can actually open.
4. **Registry** — every page declares a permission; there is no "reachable by
   omission" page.

### ⚠️ These are UX guards, not security

Every check runs on the client, which the user controls. They decide what is
*shown*, never what is *permitted*. **The API must re-authorize every request
server-side.** Hiding a route does not protect the data behind it.

The same applies to the tenant id: the client sends which tenant it believes it
is acting in, but the server must derive the authoritative tenant from the
session token and reject any mismatch. Otherwise a client that sets its own
tenant header reads every tenant on the platform.

---

## 6. Multi-tenancy

`Tenant` (`lib/core/platform/tenant.dart`) is carried on `AuthUser` and
surfaced in the header so the acting organization is always visible — the
failure mode being an admin of several tenants changing the wrong one.

Tenant-scoped querying, caching and event routing belong to the server and are
**not built**.

---

## 7. State management

| Concern | Owner |
|---|---|
| Session, permissions, tenant | `AuthProvider` (extends `AuthController`) |
| Sidebar rail / drawer / expansion | `NavigationProvider` |
| Which destination is selected | **The URL** — router pushes it into `NavigationProvider` |
| Fetched page data | `_DashboardPageState`, cached per section |

The selected section is deliberately *not* stored as provider state. The URL
owns it and the router feeds it in; a second copy is exactly how a sidebar
highlight drifts out of sync with the address bar.

No widget calls a repository directly.

---

## 8. Shell layout

```
Scaffold
 ├── Sidebar          (fixed; one ListView for shortcuts + module tree)
 └── Column
      ├── Header      (fixed — title, breadcrumb, tenant, search, bell, profile)
      └── Expanded
           └── SingleChildScrollView   ← only this scrolls
```

One scroll region. The sidebar rail uses a single `ListView`: nesting a second
viewport inside it breaks intrinsic sizing for the overlays above the shell
(the notification panel asserts).

---

## 9. Testing

189 tests. Run: `flutter test`.

| File | Covers |
|---|---|
| `permissions_test.dart` | grants, denials, registry consistency, guard rules |
| `rbac_flow_test.dart` | authorization end-to-end through the real router |
| `router_test.dart`, `navigation_test.dart` | routing, deep links, highlight sync |
| `auth_test.dart`, `flow_test.dart` | two-step sign-in |
| `pages_test.dart`, `responsive_test.dart` | layout at 375–1920px, no overflow |

Two invariants worth knowing, because they catch registry mistakes at test time
rather than in review:

- Every page permission must be grantable by some role, or the page is
  unreachable. (This caught five orphaned permissions.)
- Every role's landing page must be one that role is allowed to open.

**Note on async tests:** the shell animates continuously, so `pumpAndSettle`
never returns. Use the bounded `step()` helper, and `unawaited()` for auth
calls — awaiting them inside the test zone deadlocks.

---

## 10. Adding a module page

One entry in `kModules`:

```dart
ModulePage(slug: 'leave', title: 'Leave', permission: Perm.hrmsLeave),
```

That gives it a route, a permission-checked guard, and a sidebar row. It cannot
have one without the others. To give it a real screen, dispatch on the module
page in `DashboardPage._content` before the fallback.

---

## 11. Connecting a real backend

1. Implement `AuthBackend` against your identity service. Pass it to
   `AuthController` in `lib/main.dart`. No UI changes.
2. Implement `DashboardRepository` against your API. Pass it to `StacklyApp`.
   No widget changes.
3. Populate `AuthUser.roles` and `AuthUser.tenant` from the token claims.
4. **Re-enforce every permission server-side.** See §5.
