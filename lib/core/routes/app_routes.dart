import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/core/telemetry/telemetry_navigator_observer.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/auth/presentation/view/auth_screen.dart';
import 'package:yoopn/features/auth/presentation/view/password_screen.dart';
import 'package:yoopn/features/dashboard/presentation/view/dashboard_screen.dart';
import 'package:yoopn/features/dashboard/presentation/view/screens/info_screen.dart';
import 'package:yoopn/features/dashboard/presentation/view/screens/menu_screen.dart';
import 'package:yoopn/features/dashboard/presentation/view/screens/profile_screen.dart';
import 'package:yoopn/features/splash/presentation/view/splash_screen.dart';

/// Returns the current session without crashing when Supabase is not
/// initialized yet (e.g. router built before `main()` finishes `_init()`).
Session? _currentSession() {
  try {
    return Supabase.instance.client.auth.currentSession;
  } catch (_) {
    return null;
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppPages.splash,
  observers: [TelemetryNavigatorObserver()],
  redirect: (context, state) {
    final location = state.matchedLocation;
    AppLogger.d('ROUTE', 'redirect check location=$location');
    // Splash always decides for itself.
    if (location == AppPages.splash) return null;
    final session = _currentSession();
    final loggedIn = session != null;
    final goingHome = location == AppPages.home;
    final goingPrivate = goingHome ||
        location == AppPages.profile ||
        location == AppPages.menu ||
        location == AppPages.terms ||
        location == AppPages.safety ||
        location == AppPages.disclaimer;
    final goingAuth =
        location == AppPages.auth || location == AppPages.password;

    // Unauthenticated users may not enter the dashboard, profile, menu or
    // document pages.
    if (!loggedIn && goingPrivate) {
      AppLogger.i('ROUTE', 'guard: guest → $location blocked, redirect ${AppPages.auth}');
      return AppPages.auth;
    }
    // Authenticated users skip the login screens.
    if (loggedIn && goingAuth) {
      AppLogger.i('ROUTE', 'guard: authed user skips $location → ${AppPages.home}');
      return AppPages.home;
    }
    return null;
  },
  routes: [
    GoRoute(
      path: AppPages.splash,
      name: AppPages.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppPages.home,
      name: AppPages.home,
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: AppPages.profile,
      name: AppPages.profile,
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppPages.menu,
      name: AppPages.menu,
      builder: (context, state) => const MenuScreen(),
    ),
    GoRoute(
      path: AppPages.terms,
      name: AppPages.terms,
      builder: (context, state) => const InfoScreen(
        title: 'Terms & Conditions',
        sections: termsSections,
      ),
    ),
    GoRoute(
      path: AppPages.safety,
      name: AppPages.safety,
      builder: (context, state) => const InfoScreen(
        title: 'Safety',
        sections: safetySections,
      ),
    ),
    GoRoute(
      path: AppPages.disclaimer,
      name: AppPages.disclaimer,
      builder: (context, state) => const InfoScreen(
        title: 'Disclaimer',
        sections: disclaimerSections,
      ),
    ),
    GoRoute(
      path: AppPages.auth,
      name: AppPages.auth,
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: AppPages.password,
      name: AppPages.password,
      builder: (context, state) => const PasswordScreen(),
    ),
  ],
);
