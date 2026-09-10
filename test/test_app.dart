import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stackly_auth/features/dashboard/services/dashboard_repository.dart';
import 'package:stackly_auth/providers/auth_provider.dart';
import 'package:stackly_auth/providers/navigation_provider.dart';
import 'package:stackly_auth/router/app_router.dart';

/// Mounts the real router and the real providers against a supplied auth
/// controller, so tests exercise the same routing, guards and state wiring the
/// app uses rather than a stand-in.
class TestApp extends StatefulWidget {
  const TestApp({super.key, required this.auth, this.repository});

  /// The login form reads [AuthProvider] out of the tree, so widget tests
  /// supply that type rather than a bare controller.
  final AuthProvider auth;

  /// Defaults to a zero-latency demo repository: a pending real timer never
  /// fires inside the test fake-async zone.
  final DashboardRepository? repository;

  @override
  State<TestApp> createState() => TestAppState();
}

class TestAppState extends State<TestApp> {
  final NavigationProvider navigation = NavigationProvider();

  late final AppRouter router = AppRouter(
    auth: widget.auth,
    navigation: navigation,
    dashboardRepository:
        widget.repository ?? DemoDashboardRepository(latency: Duration.zero),
  );

  @override
  void dispose() {
    router.dispose();
    navigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NavigationProvider>.value(value: navigation),
        ChangeNotifierProvider<AuthProvider>.value(value: widget.auth),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerDelegate: router,
        routeInformationParser: const AppRouteParser(),
      ),
    );
  }
}
