import 'package:go_router/go_router.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/features/auth/presentation/view/auth_screen.dart';
import 'package:yoopn/features/auth/presentation/view/password_screen.dart';
import 'package:yoopn/features/dashboard/presentation/view/dashboard_screen.dart';
import 'package:yoopn/features/splash/presentation/view/splash_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppPages.splash,
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
