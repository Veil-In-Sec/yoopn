import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/features/auth/presentation/view/auth_screen.dart';
import 'package:yoopn/features/auth/presentation/view/password_screen.dart';
import 'package:yoopn/features/dashboard/presentation/view/dashboard_screen.dart';
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
  redirect: (context, state) {
    final location = state.matchedLocation;
    // Splash always decides for itself.
    if (location == AppPages.splash) return null;
    final session = _currentSession();
    final loggedIn = session != null;
    final goingHome = location == AppPages.home;
    final goingAuth =
        location == AppPages.auth || location == AppPages.password;

    // Unauthenticated users may not enter the dashboard.
    if (!loggedIn && goingHome) return AppPages.auth;
    // Authenticated users skip the login screens.
    if (loggedIn && goingAuth) return AppPages.home;
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
