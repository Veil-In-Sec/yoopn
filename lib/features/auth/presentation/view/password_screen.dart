import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:yoopn/core/dimentions/spacings.dart';
import 'package:yoopn/core/resources/app_assets.dart';
import 'package:yoopn/core/routes/app_pages.dart';
import 'package:yoopn/core/themes/app_colors.dart';
import 'package:yoopn/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:yoopn/features/auth/presentation/widgets/password_field.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        AuthPasswordSubmitted(_passwordController.text),
      );
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
        switch (state.status) {
          case AuthStatus.success:
            context.go(AppPages.home);
            break;
          case AuthStatus.failure:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMsg ?? 'Authentication failed'),
                backgroundColor: AppColors.error,
              ),
            );
            break;
          case AuthStatus.otpSent:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message ?? 'Please check your email'),
                backgroundColor: AppColors.primary,
              ),
            );
            break;
          case AuthStatus.initial:
          case AuthStatus.loading:
          case AuthStatus.emailSubmitted:
            break;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.textPrimary,
            ),
            onPressed: () => context.pop(),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Lottie.asset(AppAssets.passwordAnime, height: 200.h),
                    Spacing.vertical(30),
                    Text(
                      "Enter Password",
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 26.sp,
                          ),
                    ),
                    Spacing.vertical(8),
                    BlocSelector<AuthBloc, AuthState, String>(
                      selector: (state) => state.email,
                      builder: (context, email) {
                        return Text(
                          "Entering password for ${email.isNotEmpty ? email : 'your email'}",
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w900,
                              ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                    Spacing.vertical(32),
                    PasswordField(controller: _passwordController),
                    Spacing.vertical(24),
                    BlocSelector<AuthBloc, AuthState, bool>(
                      selector: (state) => state.status == AuthStatus.loading,
                      builder: (context, isLoading) {
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _submit,
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
                                    "Continue",
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
                    Spacing.vertical(50)
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
