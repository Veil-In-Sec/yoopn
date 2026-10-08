import 'package:go_router/go_router.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/features/home/presentation/view/home_screen.dart';
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
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
