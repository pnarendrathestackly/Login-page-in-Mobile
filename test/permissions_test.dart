import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';
import 'package:stackly_auth/core/platform/modules.dart';
import 'package:stackly_auth/core/platform/permissions.dart';
import 'package:stackly_auth/router/app_router.dart';

/// Authorization is a security boundary, so these tests assert the *denials*
/// as hard as the grants: a guard that only ever says yes would pass a
/// grants-only suite.
void main() {
  group('PermissionSet', () {
    test('grants exactly what a role holds, and nothing else', () {
      final perms = PermissionSet.forRoles([PlatformRole.hrManager]);

      expect(perms.can(Perm.hrmsEmployees), isTrue);
      // HR Manager deliberately excludes payroll.
      expect(perms.can(Perm.hrmsPayroll), isFalse);
      expect(perms.can(Perm.financeLedger), isFalse);
      expect(perms.can(Perm.adminUsers), isFalse);
    });

    test('the wildcard grants everything, including unknown permissions', () {
      final perms = PermissionSet.forRoles([PlatformRole.superAdmin]);

      expect(perms.can(Perm.financeApprove), isTrue);
      expect(perms.can(Perm.securityAudit), isTrue);
      // A permission added later must not need registering against the role.
      expect(perms.can('some.future.permission'), isTrue);
    });

    test('an empty set denies everything', () {
      const perms = PermissionSet.empty();

      expect(perms.can(Perm.selfService), isFalse);
      expect(perms.canAny([Perm.hrmsView, Perm.crmView]), isFalse);
      expect(perms.isEmpty, isTrue);
    });

    test('multiple roles union their permissions', () {
      final perms = PermissionSet.forRoles(
        [PlatformRole.hrManager, PlatformRole.financeManager],
      );

      expect(perms.can(Perm.hrmsEmployees), isTrue);
      expect(perms.can(Perm.financeLedger), isTrue);
      // Neither role approves payments, so the union must not either.
      expect(perms.can(Perm.financeApprove), isFalse);
    });

    test('canAll requires every permission, canAny requires one', () {
      final perms = PermissionSet.forRoles([PlatformRole.financeManager]);

      expect(perms.canAny([Perm.financeApprove, Perm.financeLedger]), isTrue);
      expect(perms.canAll([Perm.financeApprove, Perm.financeLedger]), isFalse);
    });

    test('an unknown role name falls back to least privilege, not admin', () {
      final role = PlatformRole.parse('Chief Sorcerer');
      expect(role, PlatformRole.employee);

      final perms = PermissionSet.forRoles([role]);
      expect(perms.can(Perm.adminUsers), isFalse);
      expect(perms.can(Perm.all), isFalse);
    });
  });

  group('module registry', () {
    test('every page permission is a permission some role can hold', () {
      final grantable = {
        for (final role in PlatformRole.values) ...role.permissions,
      };

      for (final module in kModules) {
        for (final page in module.pages) {
          expect(
            grantable.contains(page.permission),
            isTrue,
            reason: '${module.id}/${page.slug} requires "${page.permission}", '
                'which no role grants — the page would be unreachable.',
          );
        }
      }
    });

    test('module ids and page slugs are unique', () {
      final ids = kModules.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate module id');

      for (final module in kModules) {
        final slugs = module.pages.map((p) => p.slug).toList();
        expect(slugs.toSet().length, slugs.length,
            reason: 'duplicate page slug in ${module.id}');
      }
    });

    test('no two pages resolve to the same path', () {
      final seen = <String, String>{};
      for (final module in kModules) {
        for (final page in module.pages) {
          final path = module.pathFor(page);
          expect(seen.containsKey(path), isFalse,
              reason: 'path $path claimed by both ${seen[path]} and '
                  '${module.id}/${page.slug}');
          seen[path] = '${module.id}/${page.slug}';
        }
      }
    });

    test('visibleModules hides modules the principal cannot open at all', () {
      final hr = PermissionSet.forRoles([PlatformRole.hrManager]);
      final visible = visibleModules(hr).map((m) => m.id).toSet();

      expect(visible, contains('hrms'));
      expect(visible, isNot(contains('finance')));
      expect(visible, isNot(contains('admin')));
      expect(visible, isNot(contains('security')));
    });

    test('visiblePages hides individual pages within a visible module', () {
      final hrManager = PermissionSet.forRoles([PlatformRole.hrManager]);
      final hrms = kModulesById['hrms']!;
      final slugs = visiblePages(hrms, hrManager).map((p) => p.slug).toSet();

      expect(slugs, contains('employees'));
      // Payroll is in the module but not in this role.
      expect(slugs, isNot(contains('payroll')));
    });
  });

  group('route guards', () {
    final hr = PermissionSet.forRoles([PlatformRole.hrAdmin]);
    final admin = PermissionSet.forRoles([PlatformRole.superAdmin]);

    test('a permitted module route is allowed through unchanged', () {
      expect(
        applyGuards('/hrms/employees', AuthStatus.authenticated,
            permissions: hr),
        '/hrms/employees',
      );
    });

    test('a route the principal lacks permission for is refused with 403', () {
      expect(
        applyGuards('/finance/ledger', AuthStatus.authenticated,
            permissions: hr),
        AppRoutes.unauthorized,
      );
      expect(
        applyGuards('/admin/users', AuthStatus.authenticated, permissions: hr),
        AppRoutes.unauthorized,
      );
    });

    test('super admin reaches every registered page', () {
      for (final module in kModules) {
        for (final page in module.pages) {
          expect(
            applyGuards(module.pathFor(page), AuthStatus.authenticated,
                permissions: admin),
            module.pathFor(page),
            reason: '${module.id}/${page.slug} refused for super admin',
          );
        }
      }
    });

    test('signing out revokes access to a module route', () {
      // Same path, no session: must go to login rather than 403 — there is no
      // principal to deny yet.
      expect(
        applyGuards('/hrms/employees', AuthStatus.unauthenticated,
            permissions: const PermissionSet.empty()),
        AppRoutes.login,
      );
    });

    test('a half-finished sign-in cannot reach a protected route', () {
      // awaitingVerification: password accepted, OTP outstanding. It must be
      // treated as signed out, even if permissions were somehow supplied.
      expect(
        applyGuards('/hrms/employees', AuthStatus.awaitingVerification,
            permissions: admin),
        AppRoutes.login,
      );
    });

    test('authenticated users are bounced off the auth screens', () {
      expect(
        applyGuards(AppRoutes.login, AuthStatus.authenticated,
            permissions: admin),
        AppRoutes.home,
      );
    });

    test('an unknown page under a real module is a 404, not a 403', () {
      // Distinguishing these matters: 403 tells the user the page exists.
      expect(
        applyGuards('/hrms/nonexistent', AuthStatus.authenticated,
            permissions: admin),
        AppRoutes.notFound,
      );
    });

    test('legacy paths keep serving their existing screens', () {
      // /reports and /notifications predate the module registry; the registry
      // must not shadow them with a second route.
      expect(
        applyGuards('/reports', AuthStatus.authenticated, permissions: admin),
        '/reports',
      );
      expect(
        applyGuards('/notifications', AuthStatus.authenticated,
            permissions: admin),
        '/notifications',
      );
    });
  });

  group('landing page', () {
    test('a broadly-permitted user lands on the shared dashboard', () {
      final perms = PermissionSet.forRoles([PlatformRole.superAdmin]);
      expect(homePathFor(perms), AppRoutes.dashboard);
    });

    test('the landing page is always one the principal may open', () {
      // Every role must land somewhere it will not be immediately refused.
      for (final role in PlatformRole.values) {
        final perms = PermissionSet.forRoles([role]);
        final home = homePathFor(perms);
        expect(
          applyGuards(home, AuthStatus.authenticated, permissions: perms),
          home,
          reason: '${role.label} lands on $home but is refused there',
        );
      }
    });
  });

  group('tenant scoping', () {
    test('permissions are empty until fully authenticated', () {
      final controller =
          AuthController(DemoAuthBackend(latency: Duration.zero));
      addTearDown(controller.dispose);

      expect(controller.permissions.isEmpty, isTrue);
      expect(controller.tenant, isNull);
    });

    test('a signed-in user carries its tenant and resolved permissions',
        () async {
      final backend = DemoAuthBackend(latency: Duration.zero);
      final controller = AuthController(backend);
      addTearDown(controller.dispose);

      await controller.signIn('hr@onecloud.com', 'password123');
      // Still only half-way: no permissions yet.
      expect(controller.permissions.isEmpty, isTrue);

      await controller.verify(backend.lastCode!);

      expect(controller.tenant?.id, 'tnt_onecloud');
      expect(controller.permissions.can(Perm.hrmsPayroll), isTrue);
      expect(controller.permissions.can(Perm.financeLedger), isFalse);
    });
  });
}
