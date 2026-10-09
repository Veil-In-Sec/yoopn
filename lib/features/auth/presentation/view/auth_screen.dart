import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:yoopn/core/dimentions/spacings.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/core/utils/app_validators.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/auth/presentation/helper/auth_screen_ui_helper.dart';
import 'package:yoopn/features/auth/presentation/widgets/auth_divider.dart';
import 'package:yoopn/features/auth/presentation/widgets/auth_page_view.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const Duration _autoPlayInterval = Duration(seconds: 3);
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    AppLogger.d('UI', 'AuthScreen initState');
    startAutoPlay(_timer, _autoPlayInterval, _pageController, _currentPage);

    // Check if already authenticated via background OAuth deep link
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authBlocState = context.read<AuthBloc>().state;
        if (authBlocState.status == AuthStatus.success &&
            authBlocState.session != null) {
          context.pushReplacement(AppPages.home);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  void _submitEmail() {
    AppLogger.i('UI', 'AuthScreen Continue-with-Email tapped');
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(const AuthEmailSubmitted());
    } else {
      AppLogger.w('UI', 'AuthScreen email form invalid');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.errorMsg != curr.errorMsg ||
          prev.message != curr.message,
      listener: (context, state) {
        AppLogger.i('UI', 'AuthScreen listener status=${state.status} err=${state.errorMsg} msg=${state.message}');
        switch (state.status) {
          case AuthStatus.success:
            AppLogger.i('ROUTE', 'auth → home');
            context.pushReplacement(AppPages.home);
            break;
          case AuthStatus.emailSubmitted:
            AppLogger.i('ROUTE', 'auth → password for ${AppLogger.maskEmail(state.email)}');
            context.push(AppPages.password);
            break;
          case AuthStatus.otpSent:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message ?? 'Verification code sent to email',
                ),
                backgroundColor: AppColors.primary,
              ),
            );
            showOtpDialog(context, state.email);
            break;
          case AuthStatus.failure:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMsg ?? 'Authentication failed'),
                backgroundColor: AppColors.error,
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
                      onPageChanged: (index) => _currentPage.value = index,
                      itemCount: pages.length,
                      itemBuilder: (context, index) {
                        final pageData = pages[index];
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double opacity;
                            if (_pageController.position.haveDimensions) {
                              final page =
                                  _pageController.page ??
                                  _pageController.initialPage.toDouble();
                              opacity = (1.0 - (index - page).abs()).clamp(
                                0.0,
                                1.0,
                              );
                            } else {
                              opacity = index == _pageController.initialPage
                                  ? 1.0
                                  : 0.0;
                            }
                            return Opacity(opacity: opacity, child: child);
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
                  Spacing.vertical(20),
                  RPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextFormField(
                      keyboardType: TextInputType.emailAddress,
                      validator: AppValidators.validateEmail,
                      onChanged: (value) =>
                          context.read<AuthBloc>().add(AuthEmailChanged(value)),
                      decoration: const InputDecoration(
                        hintText: "Enter your email address",
                      ),
                    ),
                  ),
                  Spacing.vertical(15),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isAnyLoading = state.status == AuthStatus.loading;
                      final isEmailLoading = isAnyLoading &&
                          state.loadingAction == AuthLoadingAction.email;
              
                      return RPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ElevatedButton(
                          onPressed: isAnyLoading ? null : _submitEmail,
                          child: isEmailLoading
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
                      final isAnyLoading = state.status == AuthStatus.loading;
                      final isGoogleLoading = isAnyLoading &&
                          state.loadingAction == AuthLoadingAction.google;
              
                      return RPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: OutlinedButton(
                          onPressed: isAnyLoading
                              ? null
                              : () {
                                  AppLogger.i(
                                    'UI',
                                    'AuthScreen Continue-with-Google tapped',
                                  );
                                  context.read<AuthBloc>().add(
                                    const AuthGoogleSubmitted(),
                                  );
                                },
                          child: isGoogleLoading
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
