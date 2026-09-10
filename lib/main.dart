import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth.dart';
import './features/dashboard/services/dashboard_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/navigation_provider.dart';
import 'router/app_router.dart';

void main() => runApp(const StacklyApp());

const kIndigo = Color(0xFF5B4BE1);
const kInk = Color(0xFF161329);
const kMuted = Color(0xFF6B7280);
const kBorder = Color(0xFFE5E7EB);

/// App initialization only: providers, theme, and router setup. The route
/// table itself lives in `router/app_router.dart`.
class StacklyApp extends StatefulWidget {
  const StacklyApp({super.key, this.dashboardRepository});

  /// Injectable so tests (and a real API later) can supply their own.
  final DashboardRepository? dashboardRepository;

  @override
  State<StacklyApp> createState() => _StacklyAppState();
}

class _StacklyAppState extends State<StacklyApp> {
  late final AuthProvider _auth = AuthProvider(DemoAuthBackend());
  late final NavigationProvider _navigation = NavigationProvider();
  late final AppRouter _router = AppRouter(
    auth: _auth,
    navigation: _navigation,
    dashboardRepository: widget.dashboardRepository,
  );

  @override
  void dispose() {
    _router.dispose();
    _navigation.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Registered once, at the root: every screen reads the same instances,
    // and nothing below constructs a provider of its own.
    return MultiProvider(
      providers: [
        // `.value` because this State owns the lifetime and disposes them —
        // letting the provider dispose them too would double-dispose.
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        ChangeNotifierProvider<NavigationProvider>.value(value: _navigation),
      ],
      child: MaterialApp.router(
        title: 'TheStackly',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF1F0FB),
          colorScheme: ColorScheme.fromSeed(seedColor: kIndigo),
          fontFamily: 'Roboto',
        ),
        routerDelegate: _router,
        routeInformationParser: const AppRouteParser(),
      ),
    );
  }
}
