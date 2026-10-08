import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:yoopn/core/dimentions/spacings.dart';
import 'package:yoopn/core/resources/app_assets.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_validators.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/auth/presentation/helper/auth_page_data.dart';
import 'package:yoopn/features/auth/presentation/widgets/auth_divider.dart';
import 'package:yoopn/features/auth/presentation/widgets/auth_page_view.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  static const List<AuthPageData> _pages = [
    AuthPageData(
      lottiePath: AppAssets.securityAnime,
      title: "Secure & Protected",
      subtitle:
          "Your information is secured by \nPost Quantum realtime encryption.",
    ),
    AuthPageData(
      lottiePath: AppAssets.vpnAnime,
      title: "Break Borders,\nBrowse Anywhere",
      subtitle:
          "Access blocked content globally, \nany websites, anytime, anywhere.",
    ),
    AuthPageData(
      lottiePath: AppAssets.speedAnime,
      title: "Fast & Stable",
      subtitle:
          "High speed server worldwide everywhere, \nno drops or waiting.",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _pages.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        switch (state.status) {
          case AuthStatus.success:
            context.pushReplacement(AppPages.home);
            break;
          case AuthStatus.failure:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMsg ?? 'Authentication failed'),
              ),
            );
            break;
          case AuthStatus.initial:
          case AuthStatus.loading:
            break;
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 360.h,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        final pageData = _pages[index];
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double opacity = 1.0;
                            if (_pageController.position.haveDimensions) {
                              final page = _pageController.page ??
                                  _currentPage.toDouble();
                              opacity =
                                  (1.0 - (index - page).abs()).clamp(0.0, 1.0);
                            } else {
                              opacity = index == _currentPage ? 1.0 : 0.0;
                            }

                            return Opacity(
                              opacity: opacity,
                              child: child,
                            );
                          },
                          child: AuthPageView(
                            lottiePath: pageData.lottiePath,
                            title: pageData.title,
                            subtitle: pageData.subtitle,
                          ),
                        );
                      },
                    ),
                  ),
                  Spacing.vertical(10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        height: 8.h,
                        width: _currentPage == index ? 24.w : 8.w,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ),
                  ),
                  Spacing.vertical(20),
                  RPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextFormField(
                      keyboardType: TextInputType.emailAddress,
                      validator: AppValidators.validateEmail,
                      onChanged: (value) => context
                          .read<AuthBloc>()
                          .add(AuthEmailChanged(value)),
                      decoration: const InputDecoration(
                        hintText: "Enter your email address",
                      ),
                    ),
                  ),
                  Spacing.vertical(15),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state.status == AuthStatus.loading;
                      return RPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  if (_formKey.currentState?.validate() ??
                                      false) {
                                    context
                                        .read<AuthBloc>()
                                        .add(const AuthEmailSubmitted());
                                  }
                                },
                          child: isLoading
                              ? SizedBox(
                                  height: 20.h,
                                  width: 20.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onPrimary,
                                  ),
                                )
                              : Text(
                                  "Continue with Email",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.onPrimary,
                                        fontSize: 14.sp,
                                      ),
                                ),
                        ),
                      );
                    },
                  ),
                  Spacing.vertical(15),
                  RPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: const AuthDivider(),
                  ),
                  Spacing.vertical(15),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state.status == AuthStatus.loading;
                      return RPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () => context
                                  .read<AuthBloc>()
                                  .add(const AuthGoogleSubmitted()),
                          child: isLoading
                              ? SizedBox(
                                  height: 20.h,
                                  width: 20.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : Text(
                                  "Continue with Google",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                        fontSize: 14.sp,
                                      ),
                                ),
                        ),
                      );
                    },
                  ),
                  Spacing.vertical(30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
